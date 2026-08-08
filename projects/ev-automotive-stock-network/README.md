# Market-Neutral EV/Automotive Stock Network

## Business Question

After removing broad market exposure, which EV and automotive firms remain structurally connected through residual stock-return co-movement?

## Methods

- Download adjusted close prices for EV, automotive, supplier, semiconductor, and battery-related tickers
- Compute daily returns
- Remove market-wide effects by regressing each stock return against SPY returns
- Build a residual-correlation network
- Keep edges above a configurable absolute-correlation threshold
- Compute connected components, clustering, triangles, degree centrality, betweenness, eigenvector centrality, and PageRank
- Compare the observed graph against Erdos-Renyi random-graph baselines
- Prepare link-prediction features for stock co-movement relationships

## Resume Result

The resume-backed version used a 39-node residual-correlation network over 2022-2026 stock returns and reported a Node2Vec link-prediction mean ROC-AUC of 0.87.

## Artifact Status

The source notebook was found in the local `auto_network_project` folder and added here as the primary GitHub-viewable artifact.

## Files

- `notebooks/auto_network.ipynb` - GitHub-viewable source notebook
- `src/build_stock_network.py` - reproducible script for data pull, residualization, network build, and graph metrics
- `outputs/` - generated output directory when the script is run

## How To Reproduce

```bash
pip install -r requirements.txt
python src/build_stock_network.py --start 2022-01-01 --end 2026-01-01 --threshold 0.35 --output outputs
```
