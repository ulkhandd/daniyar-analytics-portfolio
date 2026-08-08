# Fraud Detection With Boosting

## Business Question

Can boosting improve fraud detection on highly imbalanced transaction data compared with simpler baseline classifiers?

## Methods

- Compared boosting against logistic regression and a single decision-tree baseline
- Tracked training error and test error across boosting iterations
- Reviewed sample-weight evolution and weak-learner contribution
- Evaluated fraud-screening performance using precision, recall, F1 score, PR-AUC, and confusion matrices
- Prioritized fraud recall and false-positive trade-offs over raw accuracy

## Data

The raw `creditcard.csv` dataset is excluded from GitHub because of size and source-data constraints.

## Files

- `notebooks/fraud_detection.ipynb` - fraud detection notebook with AdaBoost, baselines, class-imbalance analysis, and model evaluation
