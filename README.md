[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/xfVbwuLD)
# [Group3] 台灣電影票房預測
The goals of this project.

## Contributors
|組員|系級|學號|工作分配|
|-|-|-|-|
|李承儒|資科碩一|114753214|票房預測模型、DEMO app|
|曾靖雯|資科碩一|114753206|進階視覺化與降維分析|
|劉立翔|資科碩一|114753205|資料清洗、海報設計|
|陳梓銜|資碩計一|115753211|評分預測模型|
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

## Folder organization and its related description
idea by Noble WS (2009) [A Quick Guide to Organizing Computational Biology Projects.](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1000424) PLoS Comput Biol 5(7): e1000424.

### docs
* Your presentation, 1142_DS-FP_groupID.ppt/pptx/pdf (i.e.,1142_DS-FP_group1.ppt), by **06.09**
* Any related document for the project, i.e.,
  * discussion log
  * software user guide

### data
* Input
  * Source
  * Format
  * Size

### code
* Analysis steps
* Which method or package do you use?
* How do you perform training and evaluation?
  * Cross-validation, or extra separated data
* What is a null model for comparison?

### results
* What is your performance?
* Is the improvement significant?

## References
* Packages you use
* Related publications
