# Retail Loan Portfolio Analysis

## Business Question

How is a retail loan portfolio structured, and can future charge-off risk be predicted using only information available at origination?

## Data

- Loan Data 2007-2014
- 464,776 loans in the unsupervised segmentation sample
- 226,540 loans in the supervised classification sample
- Borrower and loan variables: loan amount, term, interest rate, installment, annual income, DTI, revolving balance, revolving utilization, credit history length, grade, employment length, home ownership, verification status, purpose, and listing status

The raw LendingClub dataset is excluded from GitHub because of size and source-data constraints.

## Methods

- Cleaned numeric fields stored as text
- Standardized categorical variables such as employment length
- Parsed issue and earliest credit-line dates
- Created credit-history length
- Log-transformed skewed monetary variables
- Used FAMD to handle mixed numeric and categorical features
- Applied k-means clustering on FAMD dimensions
- Compared LDA and Random Forest for Fully Paid vs Charged Off outcomes
- Tuned the Random Forest classification threshold for imbalanced bad-loan detection

## Key Results

- Identified four borrower segments: stressed high-rate borrowers, mainstream revolving-credit users, conservative small-balance borrowers, and affluent seasoned borrowers.
- LDA and default-threshold Random Forest achieved high headline accuracy but missed most charged-off loans.
- Lowering the Random Forest threshold to 0.25 raised bad-loan recall to approximately 52.8 percent and improved bad-class F1 to approximately 0.406.
- The final model is best interpreted as a screening and monitoring tool, not an automatic approval rule.

## Files

- `docs/supervised-credit-risk-report.md` - polished supervised report
- `notebooks/retail-loan-credit-risk-workflow.ipynb` - GitHub-viewable workflow reconstruction based on the reports
- `reports/Supervised_Daniyar.pdf` - original supervised report
- `reports/Unsupervised_Daniyar.pdf` - original unsupervised report
- `reports/loan_analysis_Daniyar.pptx` - presentation artifact
- `data/README.md` - raw-data handling notes
