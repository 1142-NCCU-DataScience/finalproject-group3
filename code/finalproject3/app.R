find_project_root <- function() {
  start <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  candidates <- unique(c(start, dirname(start), dirname(dirname(start))))
  marker <- file.path(candidates, "results", "model", "model_performance.csv")
  hit <- candidates[file.exists(marker)]

  if (length(hit) == 0) {
    stop("Cannot find results/model/model_performance.csv. Run code/box_office_prediction.R first.")
  }

  hit[1]
}

project_root <- find_project_root()
model_dir <- file.path(project_root, "results", "model")
lib_roots <- unique(c(
  project_root,
  dirname(project_root),
  dirname(dirname(project_root))
))
local_libs <- file.path(lib_roots, "r_lib")
local_libs <- local_libs[dir.exists(local_libs)]
if (length(local_libs) > 0) .libPaths(c(local_libs, .libPaths()))

library(shiny)
library(ggplot2)

read_model_csv <- function(filename, ...) {
  path <- file.path(model_dir, filename)
  if (!file.exists(path)) stop("Missing model output: ", path)
  read.csv(path, check.names = FALSE, stringsAsFactors = FALSE, ...)
}

performance <- read_model_csv("model_performance.csv")
importance <- read_model_csv("feature_importance_permutation.csv")
predictions <- read_model_csv("out_of_fold_predictions.csv")
processed <- read_model_csv("processed_high_revenue_dataset.csv")
raw_data_path <- file.path(project_root, "data", "data.csv")
if (!file.exists(raw_data_path)) stop("Missing raw data: ", raw_data_path)
raw_data <- read.csv(raw_data_path, check.names = FALSE, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")
raw_country_choices <- sort(unique(raw_data$國別[
  !is.na(raw_data$國別) & trimws(raw_data$國別) != ""
]))
raw_language_choices <- sort(unique(raw_data$original_language[
  !is.na(raw_data$original_language) & trimws(raw_data$original_language) != ""
]))
model_names <- performance$Model
model_columns <- setNames(gsub("[^A-Za-z0-9]+", "_", model_names), model_names)
feature_names <- intersect(c("year", "runtime", "rating", "vote_count", "popularity", "revenue"), names(processed))
best_model <- performance$Model[1]
revenue_threshold <- as.numeric(quantile(processed$revenue, 0.75, na.rm = TRUE))

model_palette <- c(
  "XGBoost" = "#2563eb",
  "Random Forest" = "#0f766e",
  "Decision Tree" = "#b45309",
  "Logistic Regression" = "#7c3aed",
  "Null Model" = "#64748b"
)
class_palette <- c("High_Revenue" = "#dc2626", "Non_High_Revenue" = "#2563eb")
correct_palette <- c("Correct" = "#0f766e", "Incorrect" = "#dc2626")

app_theme <- function(base_size = 13) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", color = "#111827"),
      plot.subtitle = element_text(color = "#4b5563"),
      panel.grid.minor = element_blank(),
      legend.position = "top",
      legend.title = element_text(face = "bold"),
      axis.title = element_text(face = "bold")
    )
}

percent_label <- function(x) paste0(round(100 * x, 1), "%")

metric_card <- function(label, output_id) {
  div(
    class = "metric",
    div(class = "metric-label", label),
    div(class = "metric-value", textOutput(output_id, inline = TRUE))
  )
}

ui <- fluidPage(
  tags$head(
    tags$title("Box Office High-Revenue Model Dashboard"),
    tags$style(HTML("
      body { background: #f5f7fb; color: #1f2937; }
      .app-header {
        background: linear-gradient(135deg, #0f172a, #1d4ed8);
        color: white;
        margin: 0 -15px 18px -15px;
        padding: 24px 30px 20px 30px;
      }
      .app-title { font-size: 28px; font-weight: 700; margin-bottom: 7px; }
      .group-title { color: #ffffff; font-size: 18px; font-weight: 700; margin-bottom: 4px; }
      .group-members { color: #bfdbfe; font-size: 13px; margin-bottom: 12px; }
      .app-subtitle { color: #dbeafe; font-size: 14px; }
      .nav-tabs { border-bottom-color: #d9dee8; margin-bottom: 16px; }
      .nav-tabs > li > a { color: #374151; font-weight: 600; }
      .nav-tabs > li.active > a,
      .nav-tabs > li.active > a:focus,
      .nav-tabs > li.active > a:hover { color: #1d4ed8; }
      .well, .tab-content {
        background: #ffffff;
        border: 1px solid #d9dee8;
        border-radius: 9px;
        box-shadow: none;
      }
      #main_nav + .tab-content { background: transparent; border: 0; padding: 0; }
      .metric-row {
        display: grid;
        grid-template-columns: repeat(4, minmax(0, 1fr));
        gap: 12px;
        margin-bottom: 15px;
      }
      .metric {
        background: #ffffff;
        border: 1px solid #d9dee8;
        border-radius: 9px;
        padding: 13px 15px;
        min-height: 82px;
      }
      .metric-label {
        color: #64748b;
        font-size: 12px;
        font-weight: 700;
        letter-spacing: .04em;
        text-transform: uppercase;
      }
      .metric-value { color: #0f172a; font-size: 23px; font-weight: 700; margin-top: 5px; }
      .metric-value .shiny-text-output { display: inline; }
      h4 { font-size: 16px; font-weight: 700; }
      @media (max-width: 980px) { .metric-row { grid-template-columns: repeat(2, 1fr); } }
      @media (max-width: 620px) { .metric-row { grid-template-columns: 1fr; } }
    "))
  ),
  div(
    class = "app-header",
    div(class = "group-title", "Group3"),
    div(class = "group-members", "Group Member: 李承儒, 曾靖雯, 劉立翔, 陳梓銜, 張淑華"),
    div(class = "app-title", "Box Office High-Revenue Model Dashboard"),
    div(
      class = "app-subtitle",
      sprintf(
        "%s rows | High revenue: revenue > %s | Stratified 6-fold cross validation",
        format(nrow(processed), big.mark = ","),
        format(round(revenue_threshold), big.mark = ",")
      )
    )
  ),
  tabsetPanel(
    id = "main_nav",
    tabPanel(
      "Model Overview",
      sidebarLayout(
        sidebarPanel(
          width = 3,
          selectInput("overview_model", "Model", choices = model_names, selected = best_model),
          selectInput(
            "overview_metric",
            "Comparison metric",
            choices = c("F1 score" = "F1_score", "Accuracy" = "Accuracy", "Precision" = "Precision", "Recall" = "Recall"),
            selected = "F1_score"
          )
        ),
        mainPanel(
          width = 9,
          div(
            class = "metric-row",
            metric_card("Accuracy", "metric_accuracy"),
            metric_card("Precision", "metric_precision"),
            metric_card("Recall", "metric_recall"),
            metric_card("F1 Score", "metric_f1")
          ),
          tabsetPanel(
            tabPanel("Model Comparison", plotOutput("performance_plot", height = "470px")),
            tabPanel("Confusion Matrix", plotOutput("confusion_plot", height = "470px")),
            tabPanel("Performance Table", tableOutput("performance_table"))
          )
        )
      )
    ),
    tabPanel(
      "Feature Importance",
      sidebarLayout(
        sidebarPanel(
          width = 3,
          selectInput(
            "importance_model",
            "Model",
            choices = unique(importance$Model),
            selected = if (best_model %in% importance$Model) best_model else unique(importance$Model)[1]
          ),
          selectInput(
            "importance_metric",
            "Permutation importance",
            choices = c("F1 score drop" = "F1_drop", "Accuracy drop" = "Accuracy_drop"),
            selected = "F1_drop"
          ),
          sliderInput("importance_top_n", "Number of features", min = 3, max = max(3, length(unique(importance$Feature))), value = min(6, length(unique(importance$Feature))))
        ),
        mainPanel(
          width = 9,
          plotOutput("importance_plot", height = "500px"),
          tableOutput("importance_table")
        )
      )
    ),
    tabPanel(
      "Prediction Explorer",
      sidebarLayout(
        sidebarPanel(
          width = 3,
          selectInput("prediction_model", "Model", choices = model_names, selected = best_model),
          selectInput("prediction_actual", "Actual class", choices = c("All", "High_Revenue", "Non_High_Revenue")),
          selectInput("prediction_result", "Prediction result", choices = c("All", "Correct", "Incorrect")),
          sliderInput("prediction_fold", "Test fold", min = 1, max = 6, value = c(1, 6), step = 1),
          sliderInput("prediction_rows", "Rows in preview table", min = 10, max = 100, value = 30, step = 10)
        ),
        mainPanel(
          width = 9,
          div(
            class = "metric-row",
            metric_card("Filtered Rows", "prediction_count"),
            metric_card("Correct", "prediction_correct"),
            metric_card("Incorrect", "prediction_incorrect"),
            metric_card("Filtered Accuracy", "prediction_accuracy")
          ),
          tabsetPanel(
            tabPanel("Revenue Plot", plotOutput("prediction_plot", height = "480px")),
            tabPanel("Preview Table", tableOutput("prediction_table"))
          )
        )
      )
    ),
    tabPanel(
      "Data Explorer",
      sidebarLayout(
        sidebarPanel(
          width = 3,
          selectInput("data_x", "X axis", choices = feature_names, selected = "popularity"),
          selectInput("data_y", "Y axis", choices = feature_names, selected = "revenue"),
          selectInput("data_color", "Color", choices = c("Revenue class" = "High_Revenue", "Genre" = "genre"), selected = "High_Revenue"),
          checkboxInput("data_log_x", "Log scale X", value = TRUE),
          checkboxInput("data_log_y", "Log scale Y", value = TRUE),
          sliderInput("data_sample", "Sample size", min = 300, max = min(5000, nrow(processed)), value = min(1800, nrow(processed)), step = 100)
        ),
        mainPanel(width = 9, plotOutput("data_plot", height = "560px"))
      )
    ),
    tabPanel(
      "Raw Data",
      sidebarLayout(
        sidebarPanel(
          width = 3,
          h4("Raw data filters"),
          selectInput("raw_country", "Country", choices = c("All", raw_country_choices), selected = "All"),
          selectInput("raw_match_status", "Match status", choices = c("All", sort(unique(raw_data$match_status))), selected = "All"),
          selectInput("raw_language", "Original language", choices = c("All", raw_language_choices), selected = "All"),
          checkboxInput("raw_matched_only", "Rows with TMDB ID only", value = FALSE),
          helpText("Use the search boxes above the table to search individual columns.")
        ),
        mainPanel(
          width = 9,
          div(
            class = "metric-row",
            metric_card("Filtered Rows", "raw_filtered_rows"),
            metric_card("Total Rows", "raw_total_rows"),
            metric_card("Columns", "raw_total_columns"),
            metric_card("Countries", "raw_total_countries")
          ),
          DT::DTOutput("raw_data_table")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  selected_performance <- reactive({
    performance[performance$Model == input$overview_model, , drop = FALSE]
  })

  output$metric_accuracy <- renderText(percent_label(selected_performance()$Accuracy))
  output$metric_precision <- renderText(percent_label(selected_performance()$Precision))
  output$metric_recall <- renderText(percent_label(selected_performance()$Recall))
  output$metric_f1 <- renderText(percent_label(selected_performance()$F1_score))

  output$performance_plot <- renderPlot({
    req(input$overview_metric)
    metric <- input$overview_metric
    dat <- performance
    dat$Value <- dat[[metric]]
    dat <- dat[is.finite(dat$Value), , drop = FALSE]
    dat$Selected <- ifelse(dat$Model == input$overview_model, "Selected", "Other")

    ggplot(dat, aes(x = reorder(Model, Value), y = Value, fill = Selected)) +
      geom_col(width = 0.66) +
      geom_text(aes(label = percent_label(Value)), hjust = -0.12, fontface = "bold") +
      coord_flip() +
      scale_fill_manual(values = c(Selected = "#2563eb", Other = "#94a3b8"), guide = "none") +
      scale_y_continuous(labels = percent_label, limits = c(0, max(dat$Value, na.rm = TRUE) * 1.18)) +
      labs(title = paste("Model comparison:", gsub("_", " ", metric)), x = NULL, y = NULL) +
      app_theme()
  })

  confusion_data <- reactive({
    filename <- paste0("confusion_matrix_", model_columns[[input$overview_model]], ".csv")
    cm <- read_model_csv(filename, row.names = 1)
    dat <- as.data.frame(as.table(as.matrix(cm)))
    names(dat) <- c("Actual", "Predicted", "Count")
    dat
  })

  output$confusion_plot <- renderPlot({
    dat <- confusion_data()
    ggplot(dat, aes(x = Predicted, y = Actual, fill = Count)) +
      geom_tile(color = "white", linewidth = 1.2) +
      geom_text(aes(label = format(Count, big.mark = ",")), fontface = "bold", size = 6) +
      scale_fill_gradient(low = "#dbeafe", high = "#1d4ed8") +
      labs(title = paste("Confusion matrix:", input$overview_model), x = "Predicted class", y = "Actual class", fill = "Count") +
      app_theme(14)
  })

  output$performance_table <- renderTable({
    dat <- performance
    metric_cols <- c("Accuracy", "Precision", "Recall", "F1_score")
    dat[metric_cols] <- lapply(dat[metric_cols], function(x) sprintf("%.2f%%", 100 * x))
    dat
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  selected_importance <- reactive({
    req(input$importance_model, input$importance_metric)
    dat <- importance[importance$Model == input$importance_model, , drop = FALSE]
    dat$Value <- dat[[input$importance_metric]]
    dat <- dat[order(dat$Value, decreasing = TRUE), , drop = FALSE]
    head(dat, input$importance_top_n)
  })

  output$importance_plot <- renderPlot({
    dat <- selected_importance()
    ggplot(dat, aes(x = reorder(Feature, Value), y = Value)) +
      geom_col(fill = "#0f766e", width = 0.66) +
      geom_text(aes(label = sprintf("%.3f", Value)), hjust = -0.12, fontface = "bold") +
      coord_flip() +
      scale_y_continuous(expand = expansion(mult = c(0, 0.18))) +
      labs(title = paste("Permutation feature importance:", input$importance_model), x = NULL, y = gsub("_", " ", input$importance_metric)) +
      app_theme()
  })

  output$importance_table <- renderTable({
    dat <- selected_importance()[, c("Feature", "Accuracy_drop", "F1_drop")]
    dat$Accuracy_drop <- round(dat$Accuracy_drop, 4)
    dat$F1_drop <- round(dat$F1_drop, 4)
    dat
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  filtered_predictions <- reactive({
    model_col <- model_columns[[input$prediction_model]]
    dat <- predictions
    dat$predicted <- dat[[model_col]]
    dat$result <- ifelse(dat$actual == dat$predicted, "Correct", "Incorrect")
    dat <- dat[dat$fold >= input$prediction_fold[1] & dat$fold <= input$prediction_fold[2], , drop = FALSE]
    if (!identical(input$prediction_actual, "All")) dat <- dat[dat$actual == input$prediction_actual, , drop = FALSE]
    if (!identical(input$prediction_result, "All")) dat <- dat[dat$result == input$prediction_result, , drop = FALSE]
    dat
  })

  output$prediction_count <- renderText(format(nrow(filtered_predictions()), big.mark = ","))
  output$prediction_correct <- renderText(format(sum(filtered_predictions()$result == "Correct"), big.mark = ","))
  output$prediction_incorrect <- renderText(format(sum(filtered_predictions()$result == "Incorrect"), big.mark = ","))
  output$prediction_accuracy <- renderText({
    dat <- filtered_predictions()
    if (nrow(dat) == 0) return("N/A")
    percent_label(mean(dat$result == "Correct"))
  })

  output$prediction_plot <- renderPlot({
    dat <- filtered_predictions()
    validate(need(nrow(dat) > 0, "No predictions match the selected filters."))
    dat <- dat[dat$revenue > 0, , drop = FALSE]
    validate(need(nrow(dat) > 0, "No positive-revenue predictions match the selected filters."))
    dat <- dat[order(dat$revenue), , drop = FALSE]
    dat$rank <- seq_len(nrow(dat))

    ggplot(dat, aes(x = rank, y = revenue, color = result)) +
      geom_point(alpha = 0.65, size = 2) +
      scale_y_log10(labels = scales::label_number(big.mark = ",")) +
      scale_color_manual(values = correct_palette) +
      labs(
        title = paste("Out-of-fold predictions:", input$prediction_model),
        subtitle = "Rows are ordered by revenue; Y axis uses a log scale.",
        x = "Revenue rank",
        y = "Revenue",
        color = "Prediction"
      ) +
      app_theme()
  })

  output$prediction_table <- renderTable({
    dat <- filtered_predictions()
    head(dat[, c("row_id", "fold", "revenue", "actual", "predicted", "result")], input$prediction_rows)
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$data_plot <- renderPlot({
    req(input$data_x, input$data_y, input$data_color)
    validate(need(input$data_x != input$data_y, "Choose different X and Y variables."))
    set.seed(123)
    dat <- processed[sample(seq_len(nrow(processed)), min(input$data_sample, nrow(processed))), , drop = FALSE]
    if (isTRUE(input$data_log_x)) dat <- dat[dat[[input$data_x]] > 0, , drop = FALSE]
    if (isTRUE(input$data_log_y)) dat <- dat[dat[[input$data_y]] > 0, , drop = FALSE]
    validate(need(nrow(dat) > 0, "No positive values are available for the selected log scales."))

    plot <- ggplot(dat, aes(x = .data[[input$data_x]], y = .data[[input$data_y]], color = .data[[input$data_color]])) +
      geom_point(alpha = 0.58, size = 2) +
      labs(
        title = paste(input$data_y, "vs", input$data_x),
        subtitle = paste("Random sample of", format(nrow(dat), big.mark = ","), "rows"),
        x = input$data_x,
        y = input$data_y,
        color = gsub("_", " ", input$data_color)
      ) +
      app_theme()

    if (isTRUE(input$data_log_x)) plot <- plot + scale_x_log10()
    if (isTRUE(input$data_log_y)) plot <- plot + scale_y_log10()
    plot
  })

  filtered_raw_data <- reactive({
    dat <- raw_data
    if (!identical(input$raw_country, "All")) dat <- dat[dat$國別 == input$raw_country, , drop = FALSE]
    if (!identical(input$raw_match_status, "All")) dat <- dat[dat$match_status == input$raw_match_status, , drop = FALSE]
    if (!identical(input$raw_language, "All")) dat <- dat[dat$original_language == input$raw_language, , drop = FALSE]
    if (isTRUE(input$raw_matched_only)) dat <- dat[!is.na(dat$tmdb_id) & dat$tmdb_id != "", , drop = FALSE]
    dat
  })

  output$raw_filtered_rows <- renderText(format(nrow(filtered_raw_data()), big.mark = ","))
  output$raw_total_rows <- renderText(format(nrow(raw_data), big.mark = ","))
  output$raw_total_columns <- renderText(ncol(raw_data))
  output$raw_total_countries <- renderText(length(unique(raw_data$國別)))

  output$raw_data_table <- DT::renderDT({
    DT::datatable(
      filtered_raw_data(),
      rownames = FALSE,
      filter = "top",
      extensions = "Scroller",
      options = list(
        pageLength = 25,
        lengthMenu = c(10, 25, 50, 100),
        scrollX = TRUE,
        scrollY = "560px",
        scroller = TRUE,
        deferRender = TRUE
      )
    )
  }, server = TRUE)
}

shinyApp(ui = ui, server = server)
