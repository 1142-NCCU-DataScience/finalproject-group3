# Box office high-revenue classification model
# Target: High_Revenue = revenue > 75th percentile
# Validation: stratified k-fold cross validation

set.seed(123)
options(stringsAsFactors = FALSE)

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- if (length(script_arg) > 0) {
  normalizePath(sub("^--file=", "", script_arg[1]), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(file.path(getwd(), "code", "box_office_prediction.R"), winslash = "/", mustWork = TRUE)
}
project_root <- dirname(dirname(script_path))

local_lib <- file.path(project_root, "r_lib")
if (dir.exists(local_lib)) {
  .libPaths(c(local_lib, .libPaths()))
}

data_path <- file.path(project_root, "data", "data.csv")
if (!file.exists(data_path)) {
  stop("Input file not found: ", data_path)
}

output_dir <- file.path(project_root, "results", "model")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

safe_num <- function(x) {
  if (is.numeric(x)) return(x)
  as.numeric(gsub("[^0-9.\\-]", "", as.character(x)))
}

safe_div <- function(a, b) {
  ifelse(is.na(b) | b == 0, NA_real_, a / b)
}

find_col <- function(data, candidates) {
  hit <- intersect(candidates, names(data))
  if (length(hit) == 0) {
    stop(paste("Missing required column. Tried:", paste(candidates, collapse = ", ")))
  }
  hit[1]
}

get_first_genre <- function(x) {
  x <- as.character(x)
  x[is.na(x) | trimws(x) == ""] <- "Unknown"
  out <- vapply(strsplit(x, "\\|", fixed = FALSE), function(z) trimws(z[1]), character(1))
  out[out == "" | is.na(out)] <- "Unknown"
  out
}

get_year <- function(x) {
  x <- as.character(x)
  parsed <- suppressWarnings(as.Date(x))
  year <- suppressWarnings(as.integer(format(parsed, "%Y")))
  fallback <- suppressWarnings(as.integer(substr(x, 1, 4)))
  year[is.na(year)] <- fallback[is.na(year)]
  year
}

make_metrics <- function(actual, predicted, positive = "High_Revenue") {
  actual <- factor(actual, levels = c("Non_High_Revenue", "High_Revenue"))
  predicted <- factor(predicted, levels = c("Non_High_Revenue", "High_Revenue"))
  cm <- table(Actual = actual, Predicted = predicted)

  tp <- cm[positive, positive]
  fp <- sum(cm[, positive]) - tp
  fn <- sum(cm[positive, ]) - tp
  accuracy <- sum(diag(cm)) / sum(cm)
  precision <- safe_div(tp, tp + fp)
  recall <- safe_div(tp, tp + fn)
  f1 <- safe_div(2 * precision * recall, precision + recall)

  list(
    metrics = data.frame(
      Accuracy = accuracy,
      Precision = precision,
      Recall = recall,
      F1_score = f1,
      row.names = NULL
    ),
    confusion_matrix = as.data.frame.matrix(cm)
  )
}

sanitize_model_name <- function(x) {
  gsub("[^A-Za-z0-9]+", "_", x)
}

raw <- read.csv(data_path, fileEncoding = "UTF-8-BOM", check.names = FALSE)

revenue_col <- find_col(raw, c("總金額", "revenue", "Revenue"))
genre_col <- find_col(raw, c("genres", "genre", "Genre"))
date_col <- find_col(raw, c("上映日", "tmdb_release_date", "release_date", "date"))
runtime_col <- find_col(raw, c("runtime", "Runtime"))
rating_col <- find_col(raw, c("vote_average", "rating", "Rating"))
vote_count_col <- find_col(raw, c("vote_count", "Vote_Count"))
popularity_col <- find_col(raw, c("popularity", "Popularity"))

has_budget <- "budget" %in% names(raw)
if (!has_budget) {
  message("Column 'budget' was not found. The model will run without budget.")
}

df <- data.frame(
  revenue = safe_num(raw[[revenue_col]]),
  genre = get_first_genre(raw[[genre_col]]),
  year = get_year(raw[[date_col]]),
  runtime = safe_num(raw[[runtime_col]]),
  rating = safe_num(raw[[rating_col]]),
  vote_count = safe_num(raw[[vote_count_col]]),
  popularity = safe_num(raw[[popularity_col]])
)

if (has_budget) {
  df$budget <- safe_num(raw[["budget"]])
}

feature_cols <- intersect(
  c("genre", "year", "runtime", "budget", "rating", "vote_count", "popularity"),
  names(df)
)

df <- df[, c("revenue", feature_cols)]
df <- df[complete.cases(df), ]
df <- df[!is.na(df$revenue), ]

revenue_q75 <- as.numeric(quantile(df$revenue, probs = 0.75, na.rm = TRUE))
df$High_Revenue <- ifelse(df$revenue > revenue_q75, "High_Revenue", "Non_High_Revenue")
df$High_Revenue <- factor(df$High_Revenue, levels = c("Non_High_Revenue", "High_Revenue"))
df$genre <- factor(df$genre)

if ("year" %in% names(df)) {
  df$year <- as.integer(df$year)
}

write.csv(
  df,
  file.path(output_dir, "processed_high_revenue_dataset.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

k <- 6
fold_id <- integer(nrow(df))
for (idx in split(seq_len(nrow(df)), df$High_Revenue)) {
  fold_id[idx] <- sample(rep(seq_len(k), length.out = length(idx)))
}
df$fold <- fold_id

fold_summary <- as.data.frame.matrix(table(Fold = df$fold, Class = df$High_Revenue))
fold_summary$Fold <- rownames(fold_summary)
fold_summary <- fold_summary[, c("Fold", "Non_High_Revenue", "High_Revenue")]
rownames(fold_summary) <- NULL
write.csv(fold_summary, file.path(output_dir, "cv_fold_summary.csv"), row.names = FALSE, fileEncoding = "UTF-8")

split_scheme <- do.call(rbind, lapply(seq_len(k), function(i) {
  validation_fold <- i
  test_fold <- ifelse(i == k, 1, i + 1)
  training_folds <- setdiff(seq_len(k), c(validation_fold, test_fold))

  data.frame(
    Round = i,
    Validation = paste0("fold", validation_fold),
    Test = paste0("fold", test_fold),
    Training = paste(paste0("fold", training_folds), collapse = ", "),
    row.names = NULL
  )
}))
write.csv(split_scheme, file.path(output_dir, "cv_split_scheme.csv"), row.names = FALSE, fileEncoding = "UTF-8")

model_formula <- as.formula(paste("High_Revenue ~", paste(feature_cols, collapse = " + ")))
model_names <- c("Null Model", "Logistic Regression", "Decision Tree", "Random Forest", "XGBoost")

predictions <- data.frame(
  row_id = seq_len(nrow(df)),
  fold = df$fold,
  revenue = df$revenue,
  actual = df$High_Revenue
)
for (model_name in model_names) {
  predictions[[sanitize_model_name(model_name)]] <- NA_character_
}

importance_records <- list()
importance_i <- 1

make_xgb_matrix <- function(data, expected_cols = NULL) {
  x <- stats::model.matrix(model_formula, data = data)
  x <- x[, colnames(x) != "(Intercept)", drop = FALSE]
  colnames(x) <- make.names(colnames(x), unique = TRUE)

  if (!is.null(expected_cols)) {
    missing_cols <- setdiff(expected_cols, colnames(x))
    if (length(missing_cols) > 0) {
      zeros <- matrix(0, nrow = nrow(x), ncol = length(missing_cols))
      colnames(zeros) <- missing_cols
      x <- cbind(x, zeros)
    }
    x <- x[, expected_cols, drop = FALSE]
  }
  x
}

add_permutation_importance <- function(model_name, fold, test, predict_fun, base_pred) {
  base_metrics <- make_metrics(test$High_Revenue, base_pred)$metrics

  for (feature in feature_cols) {
    permuted <- test
    permuted[[feature]] <- sample(permuted[[feature]])
    perm_pred <- predict_fun(permuted)
    perm_metrics <- make_metrics(test$High_Revenue, perm_pred)$metrics

    importance_records[[importance_i]] <<- data.frame(
      Model = model_name,
      Fold = fold,
      Feature = feature,
      Accuracy_drop = base_metrics$Accuracy - perm_metrics$Accuracy,
      F1_drop = base_metrics$F1_score - perm_metrics$F1_score,
      row.names = NULL
    )
    importance_i <<- importance_i + 1
  }
}

for (fold in seq_len(k)) {
  validation_fold <- fold
  test_fold <- ifelse(fold == k, 1, fold + 1)
  train_folds <- setdiff(seq_len(k), c(validation_fold, test_fold))

  train <- df[df$fold %in% train_folds, ]
  validation <- df[df$fold == validation_fold, ]
  test <- df[df$fold == test_fold, ]

  train$genre <- factor(train$genre, levels = levels(df$genre))
  validation$genre <- factor(validation$genre, levels = levels(df$genre))
  test$genre <- factor(test$genre, levels = levels(df$genre))

  test_rows <- which(df$fold == test_fold)

  null_class <- names(which.max(table(train$High_Revenue)))
  null_pred <- factor(rep(null_class, nrow(test)), levels = levels(df$High_Revenue))
  predictions$Null_Model[test_rows] <- as.character(null_pred)

  logit_model <- glm(model_formula, data = train, family = binomial())
  logit_predict <- function(newdata) {
    p <- predict(logit_model, newdata = newdata, type = "response")
    factor(ifelse(p >= 0.5, "High_Revenue", "Non_High_Revenue"), levels = levels(df$High_Revenue))
  }
  logit_pred <- logit_predict(test)
  predictions$Logistic_Regression[test_rows] <- as.character(logit_pred)
  add_permutation_importance("Logistic Regression", fold, test, logit_predict, logit_pred)

  if (requireNamespace("rpart", quietly = TRUE)) {
    tree_model <- rpart::rpart(model_formula, data = train, method = "class")
    tree_predict <- function(newdata) {
      factor(predict(tree_model, newdata = newdata, type = "class"), levels = levels(df$High_Revenue))
    }
    tree_pred <- tree_predict(test)
    predictions$Decision_Tree[test_rows] <- as.character(tree_pred)
    add_permutation_importance("Decision Tree", fold, test, tree_predict, tree_pred)
  } else {
    message("Package 'rpart' is not installed. Decision Tree skipped.")
  }

  if (requireNamespace("randomForest", quietly = TRUE)) {
    rf_model <- randomForest::randomForest(
      model_formula,
      data = train,
      ntree = 500,
      importance = TRUE
    )
    rf_predict <- function(newdata) {
      factor(predict(rf_model, newdata = newdata, type = "response"), levels = levels(df$High_Revenue))
    }
    rf_pred <- rf_predict(test)
    predictions$Random_Forest[test_rows] <- as.character(rf_pred)
    add_permutation_importance("Random Forest", fold, test, rf_predict, rf_pred)
  } else {
    message("Package 'randomForest' is not installed. Random Forest skipped.")
  }

  if (requireNamespace("xgboost", quietly = TRUE)) {
    xgb_train_x <- make_xgb_matrix(train)
    xgb_test_x <- make_xgb_matrix(test, expected_cols = colnames(xgb_train_x))

    xgb_model <- xgboost::xgboost(
      x = xgb_train_x,
      y = train$High_Revenue,
      eval_metric = "logloss",
      nrounds = 100,
      max_depth = 4,
      learning_rate = 0.08,
      subsample = 0.9,
      colsample_bytree = 0.9,
      verbosity = 0
    )

    xgb_predict <- function(newdata) {
      x <- make_xgb_matrix(newdata, expected_cols = colnames(xgb_train_x))
      p <- predict(xgb_model, x)
      factor(ifelse(p >= 0.5, "High_Revenue", "Non_High_Revenue"), levels = levels(df$High_Revenue))
    }
    xgb_pred <- xgb_predict(test)
    predictions$XGBoost[test_rows] <- as.character(xgb_pred)
    add_permutation_importance("XGBoost", fold, test, xgb_predict, xgb_pred)
  } else {
    message("Package 'xgboost' is not installed. XGBoost skipped.")
  }
}

model_results <- list()
for (model_name in model_names) {
  pred_col <- sanitize_model_name(model_name)
  if (!pred_col %in% names(predictions)) next
  if (all(is.na(predictions[[pred_col]]))) next

  pred <- factor(predictions[[pred_col]], levels = levels(df$High_Revenue))
  score <- make_metrics(predictions$actual, pred)
  model_results[[model_name]] <- score

  out_path <- file.path(output_dir, paste0("confusion_matrix_", sanitize_model_name(model_name), ".csv"))
  write.csv(score$confusion_matrix, out_path, row.names = TRUE, fileEncoding = "UTF-8")
}

performance <- do.call(rbind, lapply(names(model_results), function(name) {
  cbind(Model = name, model_results[[name]]$metrics)
}))
rownames(performance) <- NULL
performance <- performance[order(-performance$F1_score, -performance$Accuracy, na.last = TRUE), ]

write.csv(performance, file.path(output_dir, "model_performance.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(predictions, file.path(output_dir, "out_of_fold_predictions.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(predictions, file.path(output_dir, "test_set_predictions.csv"), row.names = FALSE, fileEncoding = "UTF-8")

if (length(importance_records) > 0) {
  permutation_by_fold <- do.call(rbind, importance_records)
  write.csv(
    permutation_by_fold,
    file.path(output_dir, "feature_importance_permutation_by_fold.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )

  permutation_importance <- aggregate(
    cbind(Accuracy_drop, F1_drop) ~ Model + Feature,
    data = permutation_by_fold,
    FUN = mean,
    na.rm = TRUE
  )
  permutation_importance <- permutation_importance[order(permutation_importance$Model, -permutation_importance$F1_drop), ]
  write.csv(
    permutation_importance,
    file.path(output_dir, "feature_importance_permutation.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
} else {
  permutation_importance <- data.frame()
}

best_model <- performance$Model[1]
best_importance <- permutation_importance[permutation_importance$Model == best_model, ]
best_importance <- best_importance[order(-best_importance$F1_drop), ]
best_importance <- head(best_importance, 10)

png(file.path(output_dir, "feature_importance_top10.png"), width = 1000, height = 700)
if (nrow(best_importance) > 0) {
  barplot(
    best_importance$F1_drop,
    names.arg = best_importance$Feature,
    las = 2,
    main = paste("Top Feature Importance -", best_model, paste0("(", k, "-fold CV average)")),
    ylab = "Mean F1 drop after permutation",
    col = "#4472C4"
  )
} else {
  plot.new()
  text(0.5, 0.5, "No feature importance available")
}
dev.off()

summary_lines <- c(
  "Box Office High-Revenue Classification",
  paste("Dataset:", basename(data_path)),
  paste("Rows used:", nrow(df)),
  paste("Validation method: stratified", k, "fold cross validation"),
  paste("Revenue 75th percentile threshold:", format(round(revenue_q75, 0), big.mark = ",")),
  paste("High_Revenue definition: revenue >", format(round(revenue_q75, 0), big.mark = ",")),
  paste("Features used:", paste(feature_cols, collapse = ", ")),
  "Split method: in round i, fold i is validation, the next fold is test, and all remaining folds are training.",
  "Null model: within each round, always predicts the training-set majority class.",
  if (!has_budget) "Note: budget column was not found and was excluded." else NULL,
  "",
  "Fold class distribution:",
  capture.output(print(fold_summary, row.names = FALSE)),
  "",
  "Cross-validation split scheme:",
  capture.output(print(split_scheme, row.names = FALSE)),
  "",
  "Model performance from out-of-fold predictions:",
  capture.output(print(performance, row.names = FALSE)),
  "",
  paste("Best model by F1-score:", best_model),
  "",
  "Mean permutation feature importance for best model:",
  capture.output(print(best_importance, row.names = FALSE))
)

summary_conn <- file(file.path(output_dir, "model_summary.txt"), open = "w", encoding = "UTF-8")
writeLines(enc2utf8(summary_lines), summary_conn, useBytes = TRUE)
close(summary_conn)

message("Done. Outputs saved to: ", normalizePath(output_dir, winslash = "/"))
