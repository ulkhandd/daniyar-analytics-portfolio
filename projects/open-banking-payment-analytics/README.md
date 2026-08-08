# Open Banking Payment Performance Analytics

## Business Question

What drives conversion, payment value, failures, latency, and retention in an open-banking payment dataset?

## Data

- 500,000 payment records
- 203 banks
- 14 countries
- Lifecycle timestamps from creation through settlement
- Payment status, API version, failure reason, vertical, connectivity type, amount, bank, country, and customer identifiers

The full raw CSV is excluded from GitHub because it is large. A small sample is provided in `data/sample_payments.csv`, and generated summaries from the full dataset are included in `outputs/`.

## Methods

- Cleaned and standardized raw payment status values into lifecycle categories
- Built funnel conversion metrics from created to executed and settled
- Measured TPV, AOV, execution rate, failure rate, and median end-to-end latency
- Compared execution and failure rates by API version
- Analyzed failure reasons and failure stages
- Built customer RFM segments and retention-oriented summaries
- Flagged bank-level operational outliers using failure and cancellation behavior

## Key Results

- Execution rate was approximately 75.5 percent.
- Executed TPV was approximately 10.34 million.
- Median end-to-end latency was approximately 34.7 seconds.
- API v3 had the strongest execution rate, but also the highest failure rate.
- Expired payments accounted for the largest share of failed payments.
- Value was highly concentrated among a small group of high-value users.

## Files

- `src/analyze_payments.py` - reproducible analysis script
- `notebooks/payment-performance-analysis.ipynb` - sanitized analysis notebook
- `notebooks/truelayer-sandbox-api-pipeline.ipynb` - sanitized sandbox API notebook
- `notebooks/open-banking-payment-analysis-homework.ipynb` - GitHub-viewable source notebook found in the local project scan
- `data/sample_payments.csv` - small GitHub-safe sample
- `outputs/` - summary metrics generated from the full local dataset
- `reports/PaymentAnalysis_Daniyar.pptx` - presentation artifact

## How To Reproduce

Install dependencies:

```bash
pip install -r requirements.txt
```

Run on the included sample:

```bash
python src/analyze_payments.py --input data/sample_payments.csv --output outputs/sample_run
```

Run on the full local dataset:

```bash
python src/analyze_payments.py --input path/to/truelayer_analytics_test_data_set.csv --output outputs/full_run
```
