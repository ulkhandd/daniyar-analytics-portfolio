# Supervised Credit-Risk Prediction

## 1. Abstract

This report covers the supervised-learning stage of the loan analysis. The main question is whether information recorded when a loan is issued can help predict whether that loan will later be fully repaid or charged off. To keep the target variable clear, the analysis uses only two final loan statuses: Fully Paid and Charged Off.

The predictors include both loan-level and borrower-level information available at origination, such as loan amount, term, interest rate, installment, annual income, debt-to-income ratio, revolving-credit use, credit-history length, grade, employment length, home ownership, verification status, and loan purpose. After cleaning and transforming the data, two classification models were compared: Linear Discriminant Analysis (LDA), used as a simple benchmark, and Random Forest, used as the main nonlinear model.

Because the dataset contains many more fully paid loans than charged-off loans, accuracy alone is not a reliable measure of model quality. The early results made this clear. LDA and the default Random Forest model both reached fairly high accuracy, but they detected only a small share of charged-off loans. The more useful result came from the Random Forest model after lowering the classification threshold to 0.25. That adjustment improved bad-loan recall and produced a better balance between finding risky loans and avoiding unnecessary false alarms.

Overall, the supervised analysis shows that origination-time borrower and loan information does contain useful predictive signal. At the same time, the results also show that a credit-risk model is only useful if its decision threshold matches the practical purpose of the model. In this project, the final Random Forest model is best understood as a screening tool that helps identify loans that deserve closer review.

## 2. Problem, Goal, and Dataset

The goal of the supervised part of the project is to test whether future loan outcomes can be predicted from information known at the time the loan was originated. This is different from the unsupervised part of the project, where the focus was on finding borrower segments. Here, the task is more direct: use borrower and loan characteristics to distinguish between loans that end well and loans that end badly.

In practical terms, the analysis asks whether risky loans can be identified before the final outcome is known. That question matters in credit-risk work because even a partial ability to flag high-risk loans can support underwriting, pricing, portfolio monitoring, and manual review.

The dataset used for this part is the Loan Data 2007-2014 dataset. For the supervised model, the target variable was restricted to two clear final outcomes. Loans marked Fully Paid were treated as successful repayment cases, while loans marked Charged Off were treated as credit losses. Other loan statuses were removed because they do not represent a stable final outcome and would make the classification problem less clean.

The predictors describe both the loan itself and the borrower's financial position at origination. The loan variables include loan amount, term, interest rate, installment, purpose, grade, and initial listing status. The borrower and credit-profile variables include annual income, debt-to-income ratio, employment length, home ownership, verification status, delinquencies in the previous two years, recent credit inquiries, number of open accounts, public records, revolving balance, revolving utilization, and total number of accounts. A credit-history-length variable was also created by comparing the loan issue date with the borrower's earliest recorded credit line.

Before modelling, the data had to be cleaned and converted into a usable format. Numeric values stored as text were converted to numeric variables. Percent signs and commas were removed where needed. Loan term was converted into a numeric number of months, and employment length was standardized into consistent categories. Several monetary variables were strongly right-skewed, so loan amount, installment, annual income, and revolving balance were log-transformed to reduce the influence of extreme values. After these steps, the final supervised dataset contained 226,540 loans.

The modelling stage compares LDA with Random Forest. LDA is useful as a transparent benchmark because it gives a simple linear classification rule. Random Forest is more flexible and can capture nonlinear patterns and interactions between variables. Since the dataset is imbalanced, the models are evaluated not only by accuracy, but also by precision, recall, specificity, and F1 score for the charged-off class.

## 3. Main Findings

### 1. Origination-time information has real predictive value.

The results suggest that loan performance is not random with respect to the information available at origination. Variables such as loan size, installment burden, interest rate, income, debt-to-income ratio, revolving-debt use, and credit-history depth all help separate loans that are eventually repaid from loans that are charged off. This supports the use of supervised prediction rather than treating the data only as a descriptive exercise.

### 2. Default risk is shaped by several financial pressures at once.

The Random Forest importance ranking shows that the strongest predictors include loan amount, installment, interest rate, grade, annual income, revolving balance, loan term, revolving utilization, total accounts, and debt-to-income ratio. This means charged-off loans are not explained by one simple borrower characteristic. They are more closely connected to the combination of how much is borrowed, how expensive the loan is, how much existing credit pressure the borrower already has, and how strong the borrower's overall credit profile appears to be.

### 3. The classification threshold matters more than raw accuracy.

Both LDA and the Random Forest model with the default 0.50 threshold produced relatively high accuracy, but both missed most charged-off loans. That is a serious weakness in a credit-risk setting, because the minority class is often the class that matters most. Lowering the Random Forest threshold to 0.25 increased bad-loan recall substantially, although it also created more false positives. For this project, that trade-off is acceptable because the model is meant to support risk screening rather than make automatic approval decisions.

## 4. Analysis and Commentary

LDA was used as the baseline model, while Random Forest was used as the main nonlinear classifier. The comparison was useful because it tested whether a simple linear rule was enough, or whether the data required a more flexible model.

The first lesson from the model comparison is that overall accuracy can be misleading in this dataset. Fully paid loans are much more common than charged-off loans. Because of that, a model can look accurate simply by predicting the majority class most of the time. For credit-risk modelling, that is not enough. A useful model also needs to identify a meaningful share of the charged-off loans.

**Table 1. Comparison of supervised models**

| Model | Accuracy | Precision (bad) | Recall (bad) | Specificity | F1 (bad) |
|---|---:|---:|---:|---:|---:|
| LDA | 0.8126 | 0.4897 | 0.0868 | 0.9792 | 0.1474 |
| Random Forest, 0.50 threshold | 0.8142 | 0.5308 | 0.0428 | 0.9913 | 0.0792 |
| Random Forest, 0.25 threshold | 0.7120 | 0.3303 | 0.5280 | 0.7542 | 0.4064 |

The table shows why accuracy is not sufficient here. LDA reached an accuracy of 0.8126, but its recall for charged-off loans was only 0.0868. In other words, it detected fewer than 9% of the bad loans. The default Random Forest model had slightly higher accuracy at 0.8142, but its charged-off recall was even lower, at 0.0428. That means it found only about 4% of the charged-off loans.

Those results are too conservative for a credit-risk application. A lender using either model in that form would miss most of the loans that later become losses. For that reason, the Random Forest threshold was adjusted instead of leaving it at the standard 0.50 cutoff.

After the threshold was lowered to 0.25, the model became much better at identifying risky loans. Recall for the charged-off class increased to 0.5280, and the F1 score improved to 0.4064. The cost was lower overall accuracy and more false positives, meaning that some fully paid loans were also flagged as risky. This trade-off is important, but it is not necessarily a problem. In a screening context, it is usually better to flag more loans for review than to miss most of the loans that end in charge-off.

The final Random Forest model should therefore not be interpreted as an automatic decision rule. It is more useful as a prioritization tool. It can help identify loans that deserve additional attention, while the final decision would still require judgment and possibly more information than the model uses.

The variable-importance results also support the economic interpretation of the model.

**Table 2. Most important predictors in the final Random Forest model**

| Rank | Predictor | What it captures |
|---:|---|---|
| 1 | log_loan_amnt | Overall loan size |
| 2 | log_installment | Monthly repayment burden |
| 3 | int_rate | Loan pricing and perceived borrower risk |
| 4 | grade | Lender's initial credit-quality assessment |
| 5 | log_annual_inc | Borrower earning capacity |
| 6 | log_revol_bal | Existing revolving-debt burden |
| 7 | term_num | Loan maturity |
| 8 | revol_util | Intensity of revolving-credit use |
| 9 | total_acc | Depth of credit history |
| 10 | dti | Debt burden relative to income |

These variables make sense in a lending context. The model is not relying on an arbitrary pattern. It is using information connected to repayment capacity, existing debt pressure, the cost of borrowing, and the borrower's broader credit history. The strongest predictors also show why default risk should not be reduced to income alone. A high income may help, but it does not remove the risk created by a large loan, a high installment, heavy revolving-credit use, or a high debt-to-income ratio.

Taken together, the results show that the dataset contains useful predictive information, but also that model design choices matter. The best-performing specification in this project is the Random Forest model with a 0.25 threshold, because it gives the most practical balance between detecting charged-off loans and controlling the number of false alarms.

## 5. Theoretical Background

Supervised classification is a natural framework for credit-risk modelling because the goal is to assign loans to outcome categories based on borrower and loan characteristics. In this project, the target is binary: Fully Paid versus Charged Off. That structure fits the standard credit-scoring problem, where the model tries to distinguish lower-risk borrowers from higher-risk borrowers using information available before the outcome is observed.

LDA has a long history as a benchmark method in borrower classification. It is relatively simple, interpretable, and useful for comparison because it creates a linear separation rule between classes. For that reason, it appears often in classical credit-scoring work and provides a reasonable baseline for this project (Louzada, Ara, & Fernandes, 2016; Falbo, 1991).

Random Forest represents a more flexible approach. Instead of relying on one linear rule, it combines many decision trees and averages their results. This makes it better suited to situations where borrower characteristics interact in nonlinear ways. In credit-risk applications, that flexibility is useful because default is rarely driven by a single variable. It often depends on combinations of loan size, pricing, income, debt burden, credit utilization, and past credit behavior. Prior research has used Random Forest in loan-default prediction and broader credit-risk evaluation for this reason (Shi, 2011; Tang, Cai, & Ma, 2019; Zhou et al., 2023).

The comparison between LDA and Random Forest is also relevant because credit datasets are usually imbalanced. Most loans do not default, so the model can appear successful if it mainly predicts the majority class. Brown and Mues (2012) point out that class imbalance can distort evaluation when accuracy is used alone. This is why the present analysis gives special attention to recall, precision, specificity, and the F1 score for charged-off loans.

## 6. Conclusion

This supervised analysis tested whether borrower and loan information observed at origination can predict later loan outcomes. The results show that the data does contain useful signal, but they also show that the way model performance is evaluated matters heavily.

LDA provided a simple benchmark and achieved relatively high accuracy, but it missed most of the charged-off loans. The default Random Forest model had the same problem. Its accuracy looked strong, but its recall for the bad class was too low for practical credit-risk screening.

The preferred specification is the Random Forest model with the classification threshold lowered to 0.25. This model gave up some overall accuracy, but it detected a much larger share of charged-off loans and produced the strongest F1 score for the bad class. Because the main purpose of the model is to identify loans that may deserve closer attention, this trade-off is more useful than a higher-accuracy model that rarely flags risky cases.

The variable-importance results also point to a clear financial interpretation. Loan size, installment burden, interest rate, grade, income, revolving balance, loan term, revolving utilization, total accounts, and debt-to-income ratio were among the strongest predictors. These results suggest that loan outcomes are shaped by the combined effect of repayment burden, loan pricing, existing credit pressure, and the borrower's overall credit profile.

From a practical perspective, the final model should be treated as a decision-support tool rather than a replacement for human judgment. Its main value is in helping a lender prioritize applications or accounts for closer review. It could support underwriting, pricing decisions, risk monitoring, and portfolio management, but it should not be used as a fully automatic approval rule.

Overall, the supervised part of the project shows that future loan performance can be predicted to a meaningful extent using origination-time information. The strongest result comes from combining a flexible model with a decision threshold chosen for the actual business problem. Together with the unsupervised part of the project, this supervised analysis completes the broader movement from describing borrower groups to predicting realized loan outcomes.
