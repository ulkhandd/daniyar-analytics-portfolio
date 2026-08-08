"""Build a market-neutral EV and automotive stock correlation network."""

from __future__ import annotations

import argparse
from pathlib import Path

import networkx as nx
import numpy as np
import pandas as pd
from sklearn.linear_model import LinearRegression, LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import StratifiedKFold


DEFAULT_TICKERS = [
    "TSLA",
    "RIVN",
    "LCID",
    "NIO",
    "LI",
    "XPEV",
    "BYDDF",
    "GM",
    "F",
    "TM",
    "HMC",
    "VWAGY",
    "STLA",
    "MBGYY",
    "BMWYY",
    "HYMTF",
    "RACE",
    "APTV",
    "BWA",
    "MGA",
    "ON",
    "STM",
    "NVDA",
    "AMD",
    "INTC",
    "QCOM",
    "TXN",
    "ALB",
    "SQM",
    "LAC",
    "PCRFY",
    "LGCLF",
    "ENS",
    "CHPT",
    "BLNK",
    "EVGO",
    "QS",
    "PLUG",
    "BE",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start", default="2022-01-01")
    parser.add_argument("--end", default="2026-01-01")
    parser.add_argument("--threshold", type=float, default=0.35)
    parser.add_argument("--output", default="outputs")
    parser.add_argument("--tickers", nargs="*", default=DEFAULT_TICKERS)
    parser.add_argument("--market", default="SPY")
    return parser.parse_args()


def download_prices(tickers: list[str], market: str, start: str, end: str) -> pd.DataFrame:
    try:
        import yfinance as yf
    except ImportError as exc:
        raise SystemExit(
            "Install yfinance first: pip install -r requirements.txt"
        ) from exc

    raw = yf.download(
        tickers + [market],
        start=start,
        end=end,
        auto_adjust=True,
        progress=False,
        group_by="column",
        threads=True,
    )
    if isinstance(raw.columns, pd.MultiIndex):
        prices = raw["Close"].copy()
    else:
        prices = raw[["Close"]].rename(columns={"Close": market})

    prices = prices.dropna(axis=1, thresh=int(len(prices) * 0.8)).ffill().dropna()
    missing_market = market not in prices.columns
    if missing_market:
        raise ValueError(f"Market ticker {market} was not downloaded successfully")
    return prices


def residualize_returns(prices: pd.DataFrame, market: str) -> pd.DataFrame:
    returns = prices.pct_change().dropna(how="all")
    returns = returns.replace([np.inf, -np.inf], np.nan).dropna(axis=1, thresh=int(len(returns) * 0.8))
    returns = returns.dropna()

    market_returns = returns[[market]].values
    residuals: dict[str, np.ndarray] = {}
    for ticker in returns.columns:
        if ticker == market:
            continue
        model = LinearRegression()
        y = returns[ticker].values
        model.fit(market_returns, y)
        residuals[ticker] = y - model.predict(market_returns)

    return pd.DataFrame(residuals, index=returns.index)


def build_graph(residuals: pd.DataFrame, threshold: float) -> tuple[nx.Graph, pd.DataFrame]:
    corr = residuals.corr()
    graph = nx.Graph()
    graph.add_nodes_from(corr.columns)

    edges = []
    for i, source in enumerate(corr.columns):
        for target in corr.columns[i + 1 :]:
            weight = float(corr.loc[source, target])
            if abs(weight) >= threshold:
                graph.add_edge(source, target, weight=weight, abs_weight=abs(weight))
                edges.append({"source": source, "target": target, "correlation": weight})

    return graph, pd.DataFrame(edges)


def graph_metrics(graph: nx.Graph) -> pd.DataFrame:
    degree = nx.degree_centrality(graph)
    betweenness = nx.betweenness_centrality(graph, weight="abs_weight")
    pagerank = nx.pagerank(graph, weight="abs_weight") if graph.number_of_edges() else {}
    try:
        eigenvector = nx.eigenvector_centrality(graph, weight="abs_weight", max_iter=2000)
    except nx.NetworkXException:
        eigenvector = {node: np.nan for node in graph.nodes}

    rows = []
    for node in graph.nodes:
        rows.append(
            {
                "ticker": node,
                "degree": graph.degree(node),
                "degree_centrality": degree.get(node, 0.0),
                "betweenness_centrality": betweenness.get(node, 0.0),
                "eigenvector_centrality": eigenvector.get(node, np.nan),
                "pagerank": pagerank.get(node, np.nan),
                "component_size": len(nx.node_connected_component(graph, node))
                if graph.number_of_nodes()
                else 0,
            }
        )
    return pd.DataFrame(rows).sort_values(
        ["pagerank", "degree_centrality"], ascending=False
    )


def graph_summary(graph: nx.Graph, threshold: float) -> pd.DataFrame:
    components = list(nx.connected_components(graph))
    triangles = sum(nx.triangles(graph).values()) // 3
    summary = {
        "nodes": graph.number_of_nodes(),
        "edges": graph.number_of_edges(),
        "threshold": threshold,
        "density": nx.density(graph),
        "connected_components": len(components),
        "largest_component_size": max((len(c) for c in components), default=0),
        "average_clustering": nx.average_clustering(graph, weight="abs_weight")
        if graph.number_of_nodes()
        else np.nan,
        "triangles": triangles,
    }
    return pd.DataFrame(summary.items(), columns=["metric", "value"])


def erdos_renyi_baseline(graph: nx.Graph, iterations: int = 100) -> pd.DataFrame:
    n = graph.number_of_nodes()
    p = nx.density(graph)
    rows = []
    for seed in range(iterations):
        random_graph = nx.erdos_renyi_graph(n=n, p=p, seed=seed)
        rows.append(
            {
                "seed": seed,
                "edges": random_graph.number_of_edges(),
                "average_clustering": nx.average_clustering(random_graph)
                if n
                else np.nan,
                "triangles": sum(nx.triangles(random_graph).values()) // 3,
            }
        )
    return pd.DataFrame(rows)


def link_prediction_auc(graph: nx.Graph) -> pd.DataFrame:
    nodes = list(graph.nodes)
    if graph.number_of_edges() < 5 or graph.number_of_nodes() < 5:
        return pd.DataFrame([{"metric": "link_prediction_auc", "value": np.nan}])

    rows = []
    edge_set = {tuple(sorted(edge)) for edge in graph.edges}
    for i, source in enumerate(nodes):
        for target in nodes[i + 1 :]:
            label = int(tuple(sorted((source, target))) in edge_set)
            common = len(list(nx.common_neighbors(graph, source, target)))
            pref_attach = graph.degree(source) * graph.degree(target)
            rows.append(
                {
                    "source": source,
                    "target": target,
                    "label": label,
                    "common_neighbors": common,
                    "preferential_attachment": pref_attach,
                }
            )

    data = pd.DataFrame(rows)
    if data["label"].nunique() < 2:
        return pd.DataFrame([{"metric": "link_prediction_auc", "value": np.nan}])

    x = data[["common_neighbors", "preferential_attachment"]].values
    y = data["label"].values
    folds = min(5, data["label"].value_counts().min())
    if folds < 2:
        return pd.DataFrame([{"metric": "link_prediction_auc", "value": np.nan}])

    aucs = []
    cv = StratifiedKFold(n_splits=folds, shuffle=True, random_state=42)
    for train_idx, test_idx in cv.split(x, y):
        model = LogisticRegression(max_iter=1000)
        model.fit(x[train_idx], y[train_idx])
        prob = model.predict_proba(x[test_idx])[:, 1]
        aucs.append(roc_auc_score(y[test_idx], prob))

    return pd.DataFrame(
        [
            {"metric": "link_prediction_auc", "value": float(np.mean(aucs))},
            {"metric": "link_prediction_auc_std", "value": float(np.std(aucs))},
        ]
    )


def main() -> None:
    args = parse_args()
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)

    prices = download_prices(args.tickers, args.market, args.start, args.end)
    residuals = residualize_returns(prices, args.market)
    graph, edges = build_graph(residuals, args.threshold)

    residuals.to_csv(output / "residual_returns.csv")
    residuals.corr().to_csv(output / "residual_correlation_matrix.csv")
    edges.to_csv(output / "network_edges.csv", index=False)
    graph_metrics(graph).to_csv(output / "node_metrics.csv", index=False)
    graph_summary(graph, args.threshold).to_csv(output / "graph_summary.csv", index=False)
    erdos_renyi_baseline(graph).to_csv(output / "erdos_renyi_baseline.csv", index=False)
    link_prediction_auc(graph).to_csv(output / "link_prediction_summary.csv", index=False)
    nx.write_graphml(graph, output / "ev_automotive_network.graphml")
    print(f"Wrote network outputs to {output}")


if __name__ == "__main__":
    main()

