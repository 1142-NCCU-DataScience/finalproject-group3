[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/xfVbwuLD)
# [Group3] 台灣電影票房預測
台灣電影市場在 2020–2021 年疫情期間票房大幅下滑，雖於疫後逐步回升，但尚未恢復至過往高峰。我們希望片商有能力在電影上映前預測票房，以利規劃行銷資源與排片策略。

## Contributors
|組員|系級|學號|工作分配|
|-|-|-|-|
|李承儒|資科碩一|114753214|票房預測模型、DEMO app|
|曾靖雯|資科碩一|114753206|進階視覺化與降維分析|
|劉立翔|資科碩一|114753205|資料清洗、海報設計|
|陳梓銜|資科碩一|115753211|評分預測模型|
|張淑華|統計四|111304006|EDA，資料的初步探索、初步視覺化|

## Quick start
Run these commands from the project root. Both scripts read `data/data.csv` and write their outputs under `results/`.

```powershell
Rscript code/box_office_prediction.R
python code/vis.py
```

The Shiny dashboard reads the generated files under `results/model`. Deployment credentials are read from
`SHINYAPPS_ACCOUNT`, `SHINYAPPS_TOKEN`, and `SHINYAPPS_SECRET`; they are not stored in the repository.

To preview from a fresh R or RStudio session opened at the project root:

```r
library(shiny)
runApp("code/finalproject3")
```

The complete standalone Shiny application is stored in `code/finalproject3`. Publish that folder directly.
After rerunning the model, update the app's bundled results before publishing:

```r
source("code/finalproject3/finalproject3.R")
```

## 專案結構

> 資料夾設計參考自 Noble WS (2009). [A Quick Guide to Organizing Computational Biology Projects.](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1000424) *PLoS Comput Biol* 5(7): e1000424.

```text
finalproject-group3/
├── data/
│ └── data.csv # 原始輸入資料
├── code/
│ ├── box_office_prediction.R # 票房預測主程式（R）
│ ├── vis.py # 視覺化腳本（Python）
│ └── finalproject3/ # 獨立 Shiny 應用程式
│ └── finalproject3.R
├── results/
│ └── model/ # 模型輸出及效能指標
├── docs/
| ├── finalproject_group3.pptx # 期末簡報
| ├── 分工內容.docx # 組員工作分配說明
| ├── 評分預測模型分析報告.docx # 評分預測模型分析報告
| └── 進階視覺化與降維分析報告.docx # 進階視覺化與降維分析報告
└── README.md
```

### docs
| 檔案名稱 | 說明 |
|---|---|
| `finalproject_group3.pptx` | 期末簡報（含研究動機、方法、結果） |
| `分工內容.docx` | 組員工作分配說明 |
| `評分預測模型分析報告.docx` | 評分預測模型分析報告 |
| `進階視覺化與降維分析報告.docx` | 進階視覺化與降維分析報告 |
### `data`
| 項目   | 說明                    |
|--------|-------------------------|
| Input  | `data/data.csv`         |
| Source | 台灣電影資料（公開來源） |
| Format | CSV                     |

### `code`
- **分析流程**：資料清洗 → EDA → 特徵工程 → 模型訓練與評估
- **使用方法 / 套件**：R（tidyverse、shiny、…）、Python（pandas、matplotlib、…）
- **訓練與評估**：採交叉驗證（cross-validation）
- **比較基準（null model）**：以歷史平均票房作為 baseline

### `results`
- 各模型預測效能指標（RMSE、MAE、R² 等）
- 與 null model 的比較結果

### 使用套件
- **R**：`shiny`、`tidyverse`、`ggplot2`、`rsconnect`
- **Python**：`pandas`、`matplotlib`、`scikit-learn`

## References
- Noble WS (2009). A Quick Guide to Organizing Computational Biology Projects. *PLoS Comput Biol* 5(7): e1000424.
