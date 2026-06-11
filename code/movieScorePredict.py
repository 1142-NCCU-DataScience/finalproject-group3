import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression
from sklearn.tree import DecisionTreeRegressor
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from xgboost import XGBRegressor

# ==========================================
# 修正 1：啟用 Windows 內建的「微軟正黑體」以顯示中文
# ==========================================
plt.rcParams['font.sans-serif'] = ['Microsoft JhengHei'] 
plt.rcParams['axes.unicode_minus'] = False

# 1. 載入與清洗資料
df = pd.read_csv('第一人-票房資料匯出歷年票房_剔除2026_欄位提取_clean_TMDB_retry_matched.csv')

df['上映日'] = pd.to_datetime(df['上映日'], errors='coerce')
df['release_year'] = df['上映日'].dt.year
df['runtime'] = pd.to_numeric(df['runtime'], errors='coerce')
df['revenue'] = pd.to_numeric(df['總金額'], errors='coerce')

# 多標籤展開 (Genres)
genres_split = df['genres'].fillna('').str.get_dummies(sep='|').add_prefix('genre_')
df = pd.concat([df, genres_split], axis=1)

# 2. 定義特徵 (X) 與 目標 (y)
num_cols = ['popularity', 'vote_count', 'runtime', 'release_year', 'revenue']
df[num_cols] = df[num_cols].fillna(df[num_cols].median())

X_cols = num_cols + list(genres_split.columns)
X = df[X_cols]
y = df['vote_average']

# 移除 y 缺失值
valid_idx = y.notna()
X = X[valid_idx]
y = y[valid_idx]

# 3. 資料切分
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# 4. 建立四種模型清單
models = {
    'Linear Regression': LinearRegression(),
    'Decision Tree': DecisionTreeRegressor(random_state=42),
    'Random Forest': RandomForestRegressor(n_estimators=100, random_state=42),
    'XGBoost': XGBRegressor(n_estimators=100, random_state=42, objective='reg:squarederror')
}

# 5. 訓練模型與產出評估指標
results = {}
for name, model in models.items():
    model.fit(X_train, y_train)
    y_pred = model.predict(X_test)
    
    mae = mean_absolute_error(y_test, y_pred)
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))
    r2 = r2_score(y_test, y_pred)
    
    results[name] = {'MAE': round(mae, 4), 'RMSE': round(rmse, 4), 'R²': round(r2, 4)}

results_df = pd.DataFrame(results).T
print("=== 模型表現比較表 ===")
print(results_df)
print("\n")

# 6. 繪製特徵重要性
best_model = models['Random Forest'] 
importances = best_model.feature_importances_

importance_df = pd.DataFrame({
    'Feature': X.columns,
    'Importance': importances
}).sort_values(by='Importance', ascending=False).head(10)

# ==========================================
# 修正 2：加入 hue='Feature' 與 legend=False 消除 Seaborn 警告
# ==========================================
plt.figure(figsize=(10, 6))
sns.barplot(
    x='Importance', 
    y='Feature', 
    data=importance_df, 
    hue='Feature',      
    palette='viridis', 
    legend=False        
)

# 順便將圖表標題中文化，放進簡報會更專業
plt.title('Top 10 影響電影評分的關鍵特徵 (Random Forest)', fontsize=16, fontweight='bold')
plt.xlabel('特徵重要性 (Feature Importance)', fontsize=12)
plt.ylabel('特徵 (Features)', fontsize=12)
plt.tight_layout()
plt.show()