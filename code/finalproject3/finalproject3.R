script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- if (length(script_arg) > 0) {
  sub("^--file=", "", script_arg[1])
} else {
  sys.frame(1)$ofile
}
script_path <- normalizePath(script_path, winslash = "/", mustWork = TRUE)
app_dir <- dirname(script_path)
project_root <- dirname(dirname(app_dir))

source_results <- file.path(project_root, "results", "model")
target_results <- file.path(app_dir, "results", "model")
source_data <- file.path(project_root, "data", "data.csv")
target_data <- file.path(app_dir, "data", "data.csv")

if (!dir.exists(source_results)) {
  stop("Missing model results: ", source_results)
}
if (!file.exists(source_data)) stop("Missing raw data: ", source_data)

dir.create(target_results, recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(target_data), recursive = TRUE, showWarnings = FALSE)
result_files <- list.files(source_results, full.names = TRUE)
copied <- file.copy(result_files, target_results, overwrite = TRUE)
if (!all(copied)) stop("Failed to update one or more model result files.")
if (!file.copy(source_data, target_data, overwrite = TRUE)) stop("Failed to update raw data.")

message("Updated finalproject3 model results and raw data.")
