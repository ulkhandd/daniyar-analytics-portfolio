rm(list = ls())
gc()
set.seed(123)
options(scipen = 999)

# =========================
# 1. Packages
# =========================
needed <- c("data.table", "FactoMineR")
missing_pkgs <- needed[!sapply(needed, requireNamespace, quietly = TRUE)]
if (length(missing_pkgs) > 0) install.packages(missing_pkgs, dependencies = TRUE)

library(data.table)
library(FactoMineR)

# =========================
# 2. Paths
# =========================
if (file.exists("data/loan_data_2007_2014.csv")) {
  data_path <- "data/loan_data_2007_2014.csv"
} else if (file.exists("../data/loan_data_2007_2014.csv")) {
  data_path <- "../data/loan_data_2007_2014.csv"
} else {
  stop("CSV file not found")
}

# =========================
# 3. Load data
# =========================
loan <- fread(data_path, na.strings = c("", "NA", "N/A", "NULL"))

# =========================
# 4. Keep relevant variables
# =========================
vars_keep <- c(
  "id",
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

# =========================
# 5. Helper functions
# =========================
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
  
  mon_num <- unname(month_map[mon_txt])
  yy_num  <- suppressWarnings(as.integer(yy_txt))
  year_num <- ifelse(yy_num <= 68, 2000 + yy_num, 1900 + yy_num)
  
  good <- !is.na(mon_num) & !is.na(year_num)
  idx <- which(ok)[good]
  
  out[idx] <- as.Date(sprintf("%04d-%02d-01", year_num[good], mon_num[good]))
  out
}

top_levels <- function(dt, varname, top_n = 3) {
  out <- dt[, .N, by = .(cluster, level = get(varname))]
  setorder(out, cluster, -N)
  out[, rank_in_cluster := seq_len(.N), by = cluster]
  out[rank_in_cluster <= top_n]
}

# =========================
# 6. Cleaning
# =========================
num_vars <- c(
  "loan_amnt",
  "int_rate",
  "installment",
  "annual_inc",
  "dti",
  "delinq_2yrs",
  "inq_last_6mths",
  "open_acc",
  "pub_rec",
  "revol_bal",
  "revol_util",
  "total_acc"
)

num_vars <- num_vars[num_vars %in% names(loan)]
loan[, (num_vars) := lapply(.SD, to_num), .SDcols = num_vars]

if ("term" %in% names(loan)) {
  loan[, term_num := as.numeric(gsub("[^0-9]", "", term))]
}

if ("emp_length" %in% names(loan)) {
  loan[, emp_length := trimws(as.character(emp_length))]
  loan[emp_length == "< 1 year", emp_length := "<1"]
  loan[emp_length == "10+ years", emp_length := "10+"]
  loan[, emp_length := gsub(" years", "", emp_length)]
  loan[, emp_length := gsub(" year", "", emp_length)]
  loan[is.na(emp_length) | emp_length == "", emp_length := "Unknown"]
}

loan[, issue_date := parse_mon_yy(issue_d)]
loan[, earliest_cr_date := parse_mon_yy(earliest_cr_line)]
loan[, credit_history_months := as.numeric(issue_date - earliest_cr_date) / 30.4375]
loan[!is.finite(credit_history_months) | credit_history_months < 0, credit_history_months := NA_real_]

loan[, log_loan_amnt := log1p(loan_amnt)]
loan[, log_installment := log1p(installment)]
loan[, log_annual_inc := log1p(annual_inc)]
loan[, log_revol_bal := log1p(revol_bal)]

# =========================
# 7. Build final analysis dataset
# =========================
active_vars <- c(
  "log_loan_amnt",
  "term_num",
  "int_rate",
  "log_installment",
  "log_annual_inc",
  "dti",
  "delinq_2yrs",
  "inq_last_6mths",
  "open_acc",
  "pub_rec",
  "log_revol_bal",
  "revol_util",
  "total_acc",
  "credit_history_months",
  "emp_length",
  "home_ownership",
  "verification_status",
  "purpose",
  "initial_list_status"
)

profile_vars <- c(
  "loan_amnt",
  "installment",
  "annual_inc",
  "int_rate",
  "dti",
  "revol_util",
  "open_acc",
  "total_acc",
  "credit_history_months",
  "purpose",
  "home_ownership",
  "verification_status",
  "loan_status",
  "grade"
)

active_vars <- active_vars[active_vars %in% names(loan)]
profile_vars <- profile_vars[profile_vars %in% names(loan)]

final_vars <- unique(c(active_vars, profile_vars))
analysis_dt <- copy(loan[, ..final_vars])
analysis_dt <- analysis_dt[complete.cases(analysis_dt[, ..active_vars])]

cat_vars <- c(
  "emp_length",
  "home_ownership",
  "verification_status",
  "purpose",
  "initial_list_status",
  "loan_status",
  "grade"
)

cat_vars <- cat_vars[cat_vars %in% names(analysis_dt)]
analysis_dt[, (cat_vars) := lapply(.SD, as.factor), .SDcols = cat_vars]

nrow(analysis_dt)
summary(analysis_dt$credit_history_months)

# =========================
# 8. FAMD
# =========================
famd_data <- copy(analysis_dt[, ..active_vars])

famd_res <- FAMD(famd_data, ncp = 10, graph = FALSE)

eig_tbl <- as.data.frame(famd_res$eig)
colnames(eig_tbl) <- c("eigenvalue", "percent_variance", "cumulative_percent")
eig_tbl

top_contrib <- function(contrib_mat, dim_name, top_n = 10) {
  x <- sort(contrib_mat[, dim_name], decreasing = TRUE)
  head(x, top_n)
}

quanti_dim1 <- top_contrib(famd_res$quanti.var$contrib, "Dim.1", 10)
quanti_dim2 <- top_contrib(famd_res$quanti.var$contrib, "Dim.2", 10)
quanti_dim3 <- top_contrib(famd_res$quanti.var$contrib, "Dim.3", 10)

quali_dim1 <- top_contrib(famd_res$quali.var$contrib, "Dim.1", 10)
quali_dim2 <- top_contrib(famd_res$quali.var$contrib, "Dim.2", 10)
quali_dim3 <- top_contrib(famd_res$quali.var$contrib, "Dim.3", 10)

quanti_dim1
quanti_dim2
quanti_dim3

quali_dim1
quali_dim2
quali_dim3

# =========================
# 9. K selection benchmark
# =========================
set.seed(123)

coords_use <- as.data.frame(famd_res$ind$coord[, paste0("Dim.", 1:5)])

sample_n <- min(20000, nrow(coords_use))
sample_idx <- sample.int(nrow(coords_use), sample_n)
coords_sample <- coords_use[sample_idx, , drop = FALSE]

k_grid <- 2:6
k_eval <- data.frame(
  k = integer(),
  tot_withinss = numeric(),
  betweenss = numeric(),
  ch_index = numeric()
)

for (k in k_grid) {
  km_tmp <- kmeans(
    coords_sample,
    centers = k,
    nstart = 25,
    iter.max = 500,
    algorithm = "Lloyd"
  )
  
  ch <- (km_tmp$betweenss / (k - 1)) /
    (km_tmp$tot.withinss / (nrow(coords_sample) - k))
  
  k_eval <- rbind(
    k_eval,
    data.frame(
      k = k,
      tot_withinss = km_tmp$tot.withinss,
      betweenss = km_tmp$betweenss,
      ch_index = ch
    )
  )
}

k_eval

# =========================
# 10. Final k-means (k = 4)
# =========================
km_final <- kmeans(
  coords_use,
  centers = 4,
  nstart = 25,
  iter.max = 500,
  algorithm = "Lloyd"
)

analysis_dt[, cluster := factor(km_final$cluster)]

cluster_sizes <- as.data.frame(table(analysis_dt$cluster))
colnames(cluster_sizes) <- c("cluster", "n")
cluster_sizes$share_pct <- 100 * cluster_sizes$n / sum(cluster_sizes$n)
cluster_sizes

# =========================
# 11. Cluster profiles
# =========================
numeric_profile <- analysis_dt[
  ,
  .(
    n = .N,
    mean_loan_amnt = mean(loan_amnt, na.rm = TRUE),
    mean_installment = mean(installment, na.rm = TRUE),
    mean_annual_inc = mean(annual_inc, na.rm = TRUE),
    mean_int_rate = mean(int_rate, na.rm = TRUE),
    mean_dti = mean(dti, na.rm = TRUE),
    mean_revol_util = mean(revol_util, na.rm = TRUE),
    mean_open_acc = mean(open_acc, na.rm = TRUE),
    mean_total_acc = mean(total_acc, na.rm = TRUE),
    mean_credit_history_months = mean(credit_history_months, na.rm = TRUE)
  ),
  by = cluster
][order(cluster)]

numeric_profile

grade_profile <- top_levels(analysis_dt, "grade", top_n = 3)
status_profile <- top_levels(analysis_dt, "loan_status", top_n = 5)
purpose_profile <- top_levels(analysis_dt, "purpose", top_n = 3)

grade_profile
status_profile
purpose_profile

# =========================
# 12. Cluster plot
# =========================
set.seed(123)

plot_n <- min(20000, nrow(coords_use))
plot_idx <- sample.int(nrow(coords_use), plot_n)

plot(
  famd_res$ind$coord[plot_idx, "Dim.1"],
  famd_res$ind$coord[plot_idx, "Dim.2"],
  col = as.integer(analysis_dt$cluster[plot_idx]),
  pch = 16,
  cex = 0.5,
  xlab = "Dim.1",
  ylab = "Dim.2",
  main = "K-means clusters on first two FAMD dimensions (k = 4)"
)

