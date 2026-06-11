[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/xfVbwuLD)

# Group 3｜台灣電影高票房預測

台灣電影市場在 2020–2021 年疫情期間票房大幅下滑，雖於疫後逐步回升，但尚未恢復至過往高峰。我們希望片商有能力在電影上映前預測票房，以利規劃行銷資源與排片策略。

本專案整合台灣電影票房資料與 TMDB 電影資訊，建立二元分類模型，預測電影是否屬於高票房作品，並以 Shiny 互動式網頁呈現模型表現、特徵重要性、逐筆預測結果與原始資料。

## Group Members

| 組員 | 系級 | 學號 | 工作分配 |
|---|---|---:|---|
| 李承儒 | 資科碩一 | 114753214 | 票房預測模型、Shiny Demo App |
| 曾靖雯 | 資科碩一 | 114753206 | 進階視覺化與降維分析 |
| 劉立翔 | 資科碩一 | 114753205 | 資料清洗、海報設計 |
| 陳梓銜 | 資科碩一 | 115753211 | 評分預測模型 |
| 張淑華 | 統計四 | 111304006 | EDA、初步探索與視覺化 |

## DEMO Link

https://esdese0328.shinyapps.io/finalproject3/

## Project Objective

本專案將電影票房是否高於資料集票房第 75 百分位數定義為預測目標：

```text
High_Revenue = revenue > 4,718,287
```

模型使用的特徵包含：

- 電影類型 `genre`
- 上映年份 `year`
- 電影片長 `runtime`
- TMDB 評分 `rating`
- TMDB 評分人數 `vote_count`
- TMDB 人氣值 `popularity`

## Dataset

- 輸入檔案：`data/data.csv`
- 資料筆數：5,245
- 欄位數：21
- 主要票房欄位：`總金額`、`總票數`、`首週票房`
- TMDB 欄位：`tmdb_id`、`genres`、`popularity`、`vote_average`、`vote_count`、`runtime` 等
- `match_status`：表示票房電影是否成功配對至 TMDB 電影資料

## Modeling

使用分層 6-fold cross-validation 評估以下模型：

1. Null Model
2. Logistic Regression
3. Decision Tree
4. Random Forest
5. XGBoost

Null Model 在每輪皆預測訓練資料的多數類別。由於它不會預測 `High_Revenue`，其 Precision 與 F1 顯示為 `NA` 是合理結果。

### Model Performance

| Model | Accuracy | Precision | Recall | F1 Score |
|---|---:|---:|---:|---:|
| XGBoost | 83.26% | 72.67% | 52.94% | **61.25%** |
| Decision Tree | 82.42% | 69.39% | 53.09% | 60.16% |
| Random Forest | 82.59% | 70.47% | 52.25% | 60.01% |
| Logistic Regression | 80.42% | 74.83% | 32.65% | 45.46% |
| Null Model | 75.00% | NA | 0.00% | NA |

目前最佳模型為 **XGBoost**。Permutation feature importance 顯示 `popularity` 是影響模型預測最重要的特徵之一。

## Shiny Dashboard

互動式網頁位於 `code/finalproject3/`，包含以下頁面：

- **Model Overview**：比較模型 Accuracy、Precision、Recall、F1 與混淆矩陣
- **Feature Importance**：查看不同模型的 permutation feature importance
- **Prediction Explorer**：依模型、實際類別與預測結果檢查 out-of-fold predictions
- **Data Explorer**：互動探索模型使用的特徵與票房關係
- **Raw Data**：搜尋、排序及篩選全部原始資料

### Preview Locally

請先將 R/RStudio 工作目錄切換至專案根目錄，再執行：

```r
library(shiny)
runApp("code/finalproject3")
```

## Reproduce the Analysis

### Requirements

- R 4.x
- R packages：`rpart`、`randomForest`、`xgboost`、`shiny`、`ggplot2`、`DT`
- Python 3.x
- Python packages：`pandas`、`numpy`、`matplotlib`、`seaborn`、`scikit-learn`

首次使用前可安裝所需套件：

```r
install.packages(c("rpart", "randomForest", "xgboost", "shiny", "ggplot2", "DT"))
```

```powershell
python -m pip install pandas numpy matplotlib seaborn scikit-learn
```

### Run the Classification Models

從專案根目錄執行：

```powershell
Rscript code/box_office_prediction.R
```

模型結果會輸出至 `results/model/`。

### Run Exploratory Visualizations

```powershell
python code/vis.py
```

圖片會輸出至 `results/visualizations/`。

### Update the Shiny Bundle

```powershell
Rscript code/finalproject3/finalproject3.R
```

此指令會將最新的 `data/data.csv` 與 `results/model/` 複製到 `code/finalproject3/`，供本機預覽與發布使用。

## Project Structure

```text
finalproject-group3/
├── code/
│   ├── box_office_prediction.R       # 高票房分類模型與交叉驗證
│   ├── vis.py                        # EDA、PCA 與 K-Means 視覺化
│   └── finalproject3/
│       ├── app.R                     # Shiny 互動式網頁
│       ├── finalproject3.R           # 同步資料與模型結果
│       ├── data/                     # Shiny 發布用原始資料副本
│       └── results/model/            # Shiny 發布用模型結果副本
├── data/
│   └── data.csv                      # 分析輸入資料
├── docs/
│   ├── finalproject_group3.pptx      # 期末簡報
│   ├── 分工內容.docx                 # 組員工作分配說明
│   ├── 評分預測模型分析報告.docx     # 評分預測模型分析報告
│   └── 進階視覺化與降維分析報告.docx # 進階視覺化與降維分析報告
├── results/
│   └── model/                        # 模型輸出、評估結果與預測
└── README.md
```

## Main Outputs

`results/model/` 主要包含：

- `model_performance.csv`：模型整體表現
- `out_of_fold_predictions.csv`：交叉驗證逐筆預測
- `confusion_matrix_*.csv`：各模型混淆矩陣
- `feature_importance_permutation.csv`：平均 permutation feature importance
- `feature_importance_permutation_by_fold.csv`：各 fold 特徵重要性
- `processed_high_revenue_dataset.csv`：模型使用的處理後資料
- `model_summary.txt`：模型設定與結果摘要

## References

- Noble, W. S. (2009). [A Quick Guide to Organizing Computational Biology Projects](https://doi.org/10.1371/journal.pcbi.1000424). *PLoS Computational Biology*, 5(7), e1000424.
- [TMDB](https://www.themoviedb.org/)
