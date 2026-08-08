rm(list = ls())
gc()
set.seed(123)
options(scipen = 999)

# =========================================================
# Supervised credit-risk classification: Loan Data 2007-2014
# Target: Fully Paid vs Charged Off
# Final model: Random Forest with threshold tuned on validation set
# =========================================================

# -------------------------
# 1. Packages
# -------------------------
needed <- c("data.table", "MASS", "ranger")
to_install <- needed[!sapply(needed, requireNamespace, quietly = TRUE)]
if (length(to_install) > 0) install.packages(to_install, dependencies = TRUE)

library(data.table)
library(MASS)
library(ranger)

# -------------------------
# 2. Path
# -------------------------
if (file.exists("data/loan_data_2007_2014.csv")) {
  data_path <- "data/loan_data_2007_2014.csv"
} else if (file.exists("../data/loan_data_2007_2014.csv")) {
  data_path <- "../data/loan_data_2007_2014.csv"
} else {
  stop("CSV file not found")
}

# -------------------------
# 3. Load data
# -------------------------
loan <- fread(data_path, na.strings = c("", "NA", "N/A", "NULL"))

# -------------------------
# 4. Keep origination-time variables
# -------------------------
vars_keep <- c(
  "loan_status",
  "grade",
  "loan_amnt",
  "term",
  "int_rate",
  "installment",
  "emp_length",
  "home_ownership",
  "annual_inc",
  "verification_status",
  "purpose",
  "dti",
  "delinq_2yrs",
  "earliest_cr_line",
  "inq_last_6mths",
  "open_acc",
  "pub_rec",
  "revol_bal",
  "revol_util",
  "total_acc",
  "initial_list_status",
  "issue_d"
)

vars_keep <- vars_keep[vars_keep %in% names(loan)]
loan <- loan[, ..vars_keep]

# -------------------------
# 5. Target setup
# -------------------------
status_counts <- loan[, .N, by = loan_status][order(-N)]

loan_sup <- loan[loan_status %in% c("Fully Paid", "Charged Off")]
loan_sup[, target := ifelse(loan_status == "Charged Off", 1L, 0L)]

target_counts <- loan_sup[, .N, by = target][order(target)]
target_counts[, share_pct := round(100 * N / sum(N), 2)]

print(status_counts)
print(target_counts)

# -------------------------
# 6. Helper functions
# -------------------------
to_num <- function(x) {
  x <- as.character(x)
  x <- gsub("%", "", x)
  x <- gsub(",", "", x)
  x <- trimws(x)
  x[x == ""] <- NA
  as.numeric(x)
}

parse_mon_yy <- function(x) {
  x <- as.character(x)
  x <- trimws(x)
  x[x == ""] <- NA_character_
  
  month_map <- c(
    Jan = 1L, Feb = 2L, Mar = 3L, Apr = 4L,
    May = 5L, Jun = 6L, Jul = 7L, Aug = 8L,
    Sep = 9L, Oct = 10L, Nov = 11L, Dec = 12L
  )
  
  out <- rep(as.Date(NA), length(x))
  ok <- !is.na(x) & grepl("^[A-Za-z]{3}-[0-9]{2}$", x)
  
  mon_txt <- substr(x[ok], 1, 3)
  yy_txt  <- substr(x[ok], 5, 6)
  
  mon_num  <- unname(month_map[mon_txt])
  yy_num   <- suppressWarnings(as.integer(yy_txt))
  year_num <- ifelse(yy_num <= 68, 2000 + yy_num, 1900 + yy_num)
  
  good <- !is.na(mon_num) & !is.na(year_num)
  idx <- which(ok)[good]
  
  out[idx] <- as.Date(sprintf("%04d-%02d-01", year_num[good], mon_num[good]))
  out
}

safe_div <- function(a, b) {
  if (b == 0) return(NA_real_)
  a / b
}

calc_conf_mat <- function(actual, predicted) {
  table(Actual = actual, Predicted = predicted)
}

calc_metrics <- function(actual, predicted) {
  cm <- calc_conf_mat(actual, predicted)
  
  TN <- cm["good", "good"]
  FP <- cm["good", "bad"]
  FN <- cm["bad", "good"]
  TP <- cm["bad", "bad"]
  
  accuracy    <- safe_div(TP + TN, TP + TN + FP + FN)
  precision   <- safe_div(TP, TP + FP)
  recall      <- safe_div(TP, TP + FN)
  specificity <- safe_div(TN, TN + FP)
  f1_score    <- safe_div(2 * precision * recall, precision + recall)
  
  data.frame(
    Metric = c("Accuracy", "Precision_bad", "Recall_bad", "Specificity", "F1_bad"),
    Value  = round(c(accuracy, precision, recall, specificity, f1_score), 4)
  )
}

threshold_metrics <- function(probs, actual, thr) {
  pred <- ifelse(probs >= thr, "bad", "good")
  pred <- factor(pred, levels = levels(actual))
  actual <- factor(actual, levels = levels(actual))
  
  cm <- table(actual, pred)
  
  TN <- cm["good", "good"]
  FP <- cm["good", "bad"]
  FN <- cm["bad", "good"]
  TP <- cm["bad", "bad"]
  
  accuracy    <- safe_div(TP + TN, TP + TN + FP + FN)
  precision   <- safe_div(TP, TP + FP)
  recall      <- safe_div(TP, TP + FN)
  specificity <- safe_div(TN, TN + FP)
  f1_score    <- safe_div(2 * precision * recall, precision + recall)
  
  data.frame(
    threshold     = thr,
    accuracy      = round(accuracy, 4),
    precision_bad = round(precision, 4),
    recall_bad    = round(recall, 4),
    specificity   = round(specificity, 4),
    f1_bad        = round(f1_score, 4)
  )
}

# -------------------------
# 7. Cleaning and feature construction
# -------------------------
num_vars <- c(
  "loan_amnt", "int_rate", "installment", "annual_inc", "dti",
  "delinq_2yrs", "inq_last_6mths", "open_acc", "pub_rec",
  "revol_bal", "revol_util", "total_acc"
)

num_vars <- num_vars[num_vars %in% names(loan_sup)]
loan_sup[, (num_vars) := lapply(.SD, to_num), .SDcols = num_vars]

if ("term" %in% names(loan_sup)) {
  loan_sup[, term_num := as.numeric(gsub("[^0-9]", "", term))]
}

if ("emp_length" %in% names(loan_sup)) {
  loan_sup[, emp_length := trimws(as.character(emp_length))]
  loan_sup[emp_length == "< 1 year", emp_length := "<1"]
  loan_sup[emp_length == "10+ years", emp_length := "10+"]
  loan_sup[, emp_length := gsub(" years", "", emp_length)]
  loan_sup[, emp_length := gsub(" year", "", emp_length)]
  loan_sup[is.na(emp_length) | emp_length == "", emp_length := "Unknown"]
}

if (all(c("issue_d", "earliest_cr_line") %in% names(loan_sup))) {
  loan_sup[, issue_date := parse_mon_yy(issue_d)]
  loan_sup[, earliest_cr_date := parse_mon_yy(earliest_cr_line)]
  loan_sup[, credit_history_months := as.numeric(issue_date - earliest_cr_date) / 30.4375]
  loan_sup[!is.finite(credit_history_months) | credit_history_months < 0, credit_history_months := NA_real_]
  loan_sup[, issue_year := as.integer(format(issue_date, "%Y"))]
}

loan_sup[, log_loan_amnt   := log1p(loan_amnt)]
loan_sup[, log_installment := log1p(installment)]
loan_sup[, log_annual_inc  := log1p(annual_inc)]
loan_sup[, log_revol_bal   := log1p(revol_bal)]

# -------------------------
# 8. Final modelling dataset
# -------------------------
final_vars <- c(
  "target",
  "grade",
  "log_loan_amnt",
  "term_num",
  "int_rate",
  "log_installment",
  "emp_length",
  "home_ownership",
  "log_annual_inc",
  "verification_status",
  "purpose",
  "dti",
  "delinq_2yrs",
  "credit_history_months",
  "inq_last_6mths",
  "open_acc",
  "pub_rec",
  "log_revol_bal",
  "revol_util",
  "total_acc",
  "initial_list_status",
  "issue_year"
)

final_vars <- final_vars[final_vars %in% names(loan_sup)]
loan_model <- loan_sup[, ..final_vars]
loan_model <- loan_model[complete.cases(loan_model)]

loan_model[, target := factor(target, levels = c(0, 1), labels = c("good", "bad"))]

cat_vars <- c(
  "grade",
  "emp_length",
  "home_ownership",
  "verification_status",
  "purpose",
  "initial_list_status",
  "issue_year"
)

cat_vars <- cat_vars[cat_vars %in% names(loan_model)]
loan_model[, (cat_vars) := lapply(.SD, as.factor), .SDcols = cat_vars]

final_class_balance <- loan_model[, .N, by = target][order(target)]
print(final_class_balance)

# -------------------------
# 9. Train / validation / test split
# 60% train, 20% validation, 20% test
# -------------------------
good_idx <- which(loan_model$target == "good")
bad_idx  <- which(loan_model$target == "bad")

good_train <- sample(good_idx, size = round(0.6 * length(good_idx)))
good_rem   <- setdiff(good_idx, good_train)
good_valid <- sample(good_rem, size = round(0.5 * length(good_rem)))
good_test  <- setdiff(good_rem, good_valid)

bad_train <- sample(bad_idx, size = round(0.6 * length(bad_idx)))
bad_rem   <- setdiff(bad_idx, bad_train)
bad_valid <- sample(bad_rem, size = round(0.5 * length(bad_rem)))
bad_test  <- setdiff(bad_rem, bad_valid)

train_idx <- sort(c(good_train, bad_train))
valid_idx <- sort(c(good_valid, bad_valid))
test_idx  <- sort(c(good_test, bad_test))

train_dt <- loan_model[train_idx]
valid_dt <- loan_model[valid_idx]
test_dt  <- loan_model[test_idx]

train_balance <- train_dt[, .N, by = target][order(target)]
valid_balance <- valid_dt[, .N, by = target][order(target)]
test_balance  <- test_dt[, .N, by = target][order(target)]

print(train_balance)
print(valid_balance)
print(test_balance)

# -------------------------
# 10. LDA baseline
# fit on train, evaluate on test
# -------------------------
lda_fit <- lda(target ~ ., data = train_dt)

test_actual <- factor(test_dt$target, levels = levels(train_dt$target))
lda_pred  <- predict(lda_fit, newdata = test_dt)
lda_class <- factor(lda_pred$class, levels = levels(test_actual))

lda_conf_mat <- calc_conf_mat(test_actual, lda_class)
lda_metrics  <- calc_metrics(test_actual, lda_class)

lda_prob_summary <- aggregate(
  lda_pred$posterior[, "bad"],
  by = list(actual = test_actual),
  FUN = mean
)
colnames(lda_prob_summary) <- c("actual", "mean_prob_bad")

print(lda_conf_mat)
print(lda_metrics)
print(lda_prob_summary)

# -------------------------
# 11. Random Forest
# fit on train
# -------------------------
class_counts <- train_dt[, .N, by = target][order(target)]
class_weights <- c(
  good = nrow(train_dt) / (2 * class_counts[target == "good", N]),
  bad  = nrow(train_dt) / (2 * class_counts[target == "bad", N])
)

rf_fit <- ranger(
  target ~ .,
  data = train_dt,
  probability = TRUE,
  num.trees = 400,
  mtry = floor(sqrt(ncol(train_dt) - 1)),
  min.node.size = 20,
  importance = "permutation",
  class.weights = class_weights,
  seed = 123
)

# -------------------------
# 12. Threshold tuning on validation set
# -------------------------
valid_actual <- factor(valid_dt$target, levels = levels(train_dt$target))
rf_prob_valid <- predict(rf_fit, data = valid_dt)$predictions[, "bad"]

threshold_grid <- seq(0.10, 0.50, by = 0.05)

rf_threshold_table <- do.call(
  rbind,
  lapply(threshold_grid, function(thr) {
    threshold_metrics(rf_prob_valid, valid_actual, thr)
  })
)

best_row <- rf_threshold_table[which.max(rf_threshold_table$f1_bad), ]
best_threshold <- best_row$threshold[[1]]

print(rf_threshold_table)
print(best_row)

# -------------------------
# 13. Random Forest on test set
# default 0.50 and tuned threshold
# -------------------------
rf_prob_test <- predict(rf_fit, data = test_dt)$predictions[, "bad"]

rf_class_test_050 <- ifelse(rf_prob_test >= 0.50, "bad", "good")
rf_class_test_050 <- factor(rf_class_test_050, levels = levels(test_actual))

rf_conf_mat_050 <- calc_conf_mat(test_actual, rf_class_test_050)
rf_metrics_050  <- calc_metrics(test_actual, rf_class_test_050)

rf_class_test_tuned <- ifelse(rf_prob_test >= best_threshold, "bad", "good")
rf_class_test_tuned <- factor(rf_class_test_tuned, levels = levels(test_actual))

rf_conf_mat_tuned <- calc_conf_mat(test_actual, rf_class_test_tuned)
rf_metrics_tuned  <- calc_metrics(test_actual, rf_class_test_tuned)

rf_prob_summary_test <- aggregate(
  rf_prob_test,
  by = list(actual = test_actual),
  FUN = mean
)
colnames(rf_prob_summary_test) <- c("actual", "mean_prob_bad")

print(rf_conf_mat_050)
print(rf_metrics_050)

print(rf_conf_mat_tuned)
print(rf_metrics_tuned)
print(rf_prob_summary_test)

# -------------------------
# 14. Variable importance
# -------------------------
rf_importance <- data.frame(
  Variable = names(rf_fit$variable.importance),
  Importance = as.numeric(rf_fit$variable.importance)
)

rf_importance <- rf_importance[order(-rf_importance$Importance), ]
row.names(rf_importance) <- NULL
rf_importance_top15 <- head(rf_importance, 15)

print(rf_importance_top15)

# -------------------------
# 15. Final model comparison
# -------------------------
model_comparison <- rbind(
  data.frame(Model = "LDA", lda_metrics),
  data.frame(Model = "Random Forest (0.50)", rf_metrics_050),
  data.frame(Model = paste0("Random Forest (", best_threshold, ")"), rf_metrics_tuned)
)

print(model_comparison)


