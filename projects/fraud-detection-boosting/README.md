# Fraud Detection With Boosting

## Business Question

Can boosting improve fraud detection on highly imbalanced transaction data compared with simpler baseline classifiers?

## Methods

- Compared boosting against logistic regression and a single decision-tree baseline
- Tracked training error and test error across boosting iterations
- Reviewed sample-weight evolution and weak-learner contribution
- Evaluated fraud-screening performance using precision, recall, F1 score, PR-AUC, and confusion matrices
- Prioritized fraud recall and false-positive trade-offs over raw accuracy

## Artifact Status

Credit-card fraud datasets were found locally, but the completed project notebook or script was not found in the scan. This folder preserves the project as a case-study entry and marks the missing source artifact honestly.

## Files

- `notebooks/fraud-detection-boosting-workflow.ipynb` - GitHub-viewable workflow reconstruction for imbalanced fraud classification with AdaBoost
