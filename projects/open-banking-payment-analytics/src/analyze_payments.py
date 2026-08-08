"""Payment performance analytics for open-banking transaction data."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd


DATE_COLUMNS = [
    "createdat_ts",
    "lastupdatedat_ts",
    "initiated_at",
    "executed_at",
    "failed_at",
    "authorizing_at",
    "authorized_at",
    "settled_at",
]

STATUS_MAP = {
    "executed": "executed",
    "settled": "executed",
    "failed": "failed",
    "authorisationfailed": "failed",
    "authorizationfailed": "failed",
    "cancelled": "cancelled",
    "canceled": "cancelled",
    "rejected": "rejected",
    "initiated": "initiated",
    "initiating": "initiated",
    "new": "created",
    "submitted": "in_progress",
    "executing": "in_progress",
    "authorizing": "in_progress",
    "authorized": "in_progress",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="Path to payment CSV")
    parser.add_argument("--output", required=True, help="Directory for output CSVs")
    return parser.parse_args()


def load_payments(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, low_memory=False)
    for col in DATE_COLUMNS:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce")

    df["status_norm"] = df["status"].astype(str).str.strip().str.lower()
    df["status_clean"] = df["status_norm"].map(STATUS_MAP).fillna("other")
    df["is_executed"] = df["status_clean"].eq("executed")
    df["is_failed"] = df["status_clean"].eq("failed")
    df["is_cancelled"] = df["status_clean"].eq("cancelled")
    df["is_settled"] = df["settled_at"].notna() if "settled_at" in df.columns else False

    if {"createdat_ts", "executed_at"}.issubset(df.columns):
        df["e2e_latency_seconds"] = (
            df["executed_at"] - df["createdat_ts"]
        ).dt.total_seconds()
    else:
        df["e2e_latency_seconds"] = np.nan

    if "createdat_ts" in df.columns:
        df["month"] = df["createdat_ts"].dt.to_period("M").astype(str)

    return df


def pct(numerator: float, denominator: float) -> float:
    if denominator == 0 or pd.isna(denominator):
        return np.nan
    return float(numerator / denominator)


def write_overall_metrics(df: pd.DataFrame, output: Path) -> None:
    executed = df[df["is_executed"]]
    failed = df[df["is_failed"]]
    failure_reasons = failed.get("failure_reason", pd.Series(dtype=object))
    expired_failed = failure_reasons.astype(str).str.lower().eq("expired").sum()

    metrics = {
        "total_payments": len(df),
        "unique_customers": df["customer_id"].nunique() if "customer_id" in df else np.nan,
        "unique_banks": df["bank_id"].nunique() if "bank_id" in df else np.nan,
        "unique_countries": df["country_id"].nunique() if "country_id" in df else np.nan,
        "executed_payments": int(df["is_executed"].sum()),
        "execution_rate": pct(df["is_executed"].sum(), len(df)),
        "failed_payments": int(df["is_failed"].sum()),
        "failure_rate": pct(df["is_failed"].sum(), len(df)),
        "cancelled_payments": int(df["is_cancelled"].sum()),
        "executed_tpv": executed["amount_in_currency"].sum()
        if "amount_in_currency" in executed
        else np.nan,
        "executed_aov": executed["amount_in_currency"].mean()
        if "amount_in_currency" in executed
        else np.nan,
        "median_e2e_latency_seconds": executed["e2e_latency_seconds"].median(),
        "expired_share_of_failed": pct(expired_failed, len(failed)),
    }
    pd.DataFrame(metrics.items(), columns=["metric", "value"]).to_csv(
        output / "overall_metrics.csv", index=False
    )


def write_status_summary(df: pd.DataFrame, output: Path) -> None:
    summary = (
        df.groupby("status_clean", dropna=False)
        .agg(payments=("status_clean", "size"))
        .reset_index()
    )
    summary["share"] = summary["payments"] / len(df)
    summary.sort_values("payments", ascending=False).to_csv(
        output / "status_summary.csv", index=False
    )


def write_api_summary(df: pd.DataFrame, output: Path) -> None:
    if "api_version" not in df.columns:
        return
    summary = (
        df.groupby("api_version", dropna=False)
        .agg(
            payments=("id", "size"),
            executed=("is_executed", "sum"),
            failed=("is_failed", "sum"),
            cancelled=("is_cancelled", "sum"),
            tpv=("amount_in_currency", lambda s: s[df.loc[s.index, "is_executed"]].sum()),
            median_latency_seconds=(
                "e2e_latency_seconds",
                lambda s: s[df.loc[s.index, "is_executed"]].median(),
            ),
        )
        .reset_index()
    )
    summary["execution_rate"] = summary["executed"] / summary["payments"]
    summary["failure_rate"] = summary["failed"] / summary["payments"]
    summary.sort_values("api_version").to_csv(
        output / "api_version_summary.csv", index=False
    )


def write_failure_summary(df: pd.DataFrame, output: Path) -> None:
    if "failure_reason" not in df.columns:
        return
    failed = df[df["is_failed"]].copy()
    failed["failure_reason_clean"] = (
        failed["failure_reason"].fillna("missing").astype(str).str.strip().str.lower()
    )
    summary = (
        failed.groupby("failure_reason_clean", dropna=False)
        .agg(
            failed_payments=("id", "size"),
            failed_amount=("amount_in_currency", "sum"),
        )
        .reset_index()
    )
    summary["share_of_failed"] = summary["failed_payments"] / max(len(failed), 1)
    summary.sort_values("failed_payments", ascending=False).to_csv(
        output / "failure_reason_summary.csv", index=False
    )


def write_monthly_conversion(df: pd.DataFrame, output: Path) -> None:
    if "month" not in df.columns:
        return
    summary = (
        df.groupby("month")
        .agg(
            payments=("id", "size"),
            executed=("is_executed", "sum"),
            failed=("is_failed", "sum"),
            tpv=("amount_in_currency", lambda s: s[df.loc[s.index, "is_executed"]].sum()),
        )
        .reset_index()
    )
    summary["execution_rate"] = summary["executed"] / summary["payments"]
    summary["failure_rate"] = summary["failed"] / summary["payments"]
    summary["execution_rate_3m_avg"] = summary["execution_rate"].rolling(3).mean()
    summary.to_csv(output / "monthly_conversion.csv", index=False)


def score_quantile(series: pd.Series, ascending: bool) -> pd.Series:
    ranked = series.rank(method="first", ascending=ascending)
    bins = min(5, ranked.nunique())
    if bins <= 1:
        return pd.Series(3, index=series.index)
    return pd.qcut(ranked, q=bins, labels=False, duplicates="drop").astype(int) + 1


def write_rfm_summary(df: pd.DataFrame, output: Path) -> None:
    required = {"customer_id", "createdat_ts", "amount_in_currency"}
    if not required.issubset(df.columns):
        return

    executed = df[df["is_executed"]].copy()
    if executed.empty:
        return

    max_date = executed["createdat_ts"].max()
    rfm = (
        executed.groupby("customer_id")
        .agg(
            last_payment=("createdat_ts", "max"),
            frequency=("id", "size"),
            monetary=("amount_in_currency", "sum"),
        )
        .reset_index()
    )
    rfm["recency_days"] = (max_date - rfm["last_payment"]).dt.days
    rfm["r_score"] = score_quantile(rfm["recency_days"], ascending=False)
    rfm["f_score"] = score_quantile(rfm["frequency"], ascending=True)
    rfm["m_score"] = score_quantile(rfm["monetary"], ascending=True)

    conditions = [
        (rfm["r_score"] >= 4) & (rfm["f_score"] >= 4) & (rfm["m_score"] >= 4),
        (rfm["r_score"] <= 2) & ((rfm["f_score"] >= 4) | (rfm["m_score"] >= 4)),
        (rfm["r_score"] >= 4) & (rfm["frequency"] <= rfm["frequency"].median()),
        (rfm["m_score"] >= 4),
    ]
    labels = ["champion", "at_risk", "new_or_reactivated", "high_value"]
    rfm["segment"] = np.select(conditions, labels, default="standard")
    rfm.to_csv(output / "customer_rfm_segments.csv", index=False)

    segment_summary = (
        rfm.groupby("segment")
        .agg(
            customers=("customer_id", "nunique"),
            payments=("frequency", "sum"),
            tpv=("monetary", "sum"),
            median_recency_days=("recency_days", "median"),
        )
        .reset_index()
        .sort_values("tpv", ascending=False)
    )
    segment_summary.to_csv(output / "rfm_segment_summary.csv", index=False)


def write_bank_outliers(df: pd.DataFrame, output: Path) -> None:
    if "bank_id" not in df.columns:
        return
    bank = (
        df.groupby("bank_id")
        .agg(
            payments=("id", "size"),
            executed=("is_executed", "sum"),
            failed=("is_failed", "sum"),
            cancelled=("is_cancelled", "sum"),
            tpv=("amount_in_currency", lambda s: s[df.loc[s.index, "is_executed"]].sum()),
        )
        .reset_index()
    )
    bank["execution_rate"] = bank["executed"] / bank["payments"]
    bank["failure_cancel_rate"] = (bank["failed"] + bank["cancelled"]) / bank["payments"]

    eligible = bank[bank["payments"] >= max(100, int(bank["payments"].quantile(0.25)))].copy()
    std = eligible["failure_cancel_rate"].std(ddof=0)
    if std and not np.isnan(std):
        eligible["failure_cancel_zscore"] = (
            eligible["failure_cancel_rate"] - eligible["failure_cancel_rate"].mean()
        ) / std
    else:
        eligible["failure_cancel_zscore"] = 0.0
    eligible["outlier_flag"] = eligible["failure_cancel_zscore"] >= 2
    eligible.sort_values("failure_cancel_rate", ascending=False).to_csv(
        output / "bank_outliers.csv", index=False
    )


def main() -> None:
    args = parse_args()
    input_path = Path(args.input)
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)

    df = load_payments(input_path)
    write_overall_metrics(df, output)
    write_status_summary(df, output)
    write_api_summary(df, output)
    write_failure_summary(df, output)
    write_monthly_conversion(df, output)
    write_rfm_summary(df, output)
    write_bank_outliers(df, output)
    print(f"Wrote analysis outputs to {output}")


if __name__ == "__main__":
    main()

