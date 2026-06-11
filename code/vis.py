#載入必備套件
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans

#設定支援中文的字體
plt.rcParams['font.sans-serif'] = ['Microsoft JhengHei'] 
plt.rcParams['axes.unicode_minus'] = False #解決負號顯示問題

#匯入資料
file_path = "./data/data.csv"
df = pd.read_csv(file_path)

#將需要的數值欄位強制轉換為數字
num_cols = ['總金額', '首週票房', 'popularity', 'vote_average', 'vote_count', 'runtime']
for col in num_cols:
    df[col] = pd.to_numeric(df[col], errors='coerce')

#處理電影類型並轉換成繁體字
#處理多重標籤，將字串切割成列表
df['genre_list'] = df['genres'].astype(str).str.split('|')
#展開列表
df_exploded = df.explode('genre_list')
genre_mapping = {
    '动作': '動作', '冒险': '冒險', '科幻': '科幻', 
    '剧情': '劇情', '奇幻': '奇幻', '惊悚': '驚悚', 
    '喜剧': '喜劇', '动画': '動畫', '犯罪': '犯罪', 
    '家庭': '家庭', '恐怖': '恐怖', '悬疑': '懸疑', 
    '音乐': '音樂', '历史': '歷史', '爱情': '愛情', 
    '战争': '戰爭', '纪录': '紀錄', '西部': '西部', 
    '电视电影': '電視電影', 'nan': '未知'
}
#進行取代
df_exploded['genre_tw'] = df_exploded['genre_list'].map(lambda x: genre_mapping.get(x, x))

#取出展開後的前6大類型
top_6_genres = df_exploded['genre_tw'].value_counts().nlargest(6).index
df_top_exploded = df_exploded[df_exploded['genre_tw'].isin(top_6_genres)].copy()

# ==========================================
# 圖表1：Box Plot - 分布比較(使用展開後的資料)
# ==========================================
top_countries = ['美國', '日本', '中華民國']
df_box = df_top_exploded[df_top_exploded['國別'].isin(top_countries)]

plt.figure(figsize=(12, 7))
sns.boxplot(data=df_box, x='genre_tw', y='總金額', hue='國別', palette='Set2')
plt.yscale('log') 
plt.title('進階分析：不同國別與類型電影的票房分布差異')
plt.xlabel('電影標籤 (包含複合類型)')
plt.ylabel('總票房 (新台幣 - 對數尺度)')
plt.legend(title='國別', bbox_to_anchor=(1.05, 1), loc='upper left')
plt.tight_layout()
plt.show()

# ==========================================
# 圖表2：Scatter Plot - 變數關係分析(使用展開後的資料)
# ==========================================
#建立分面圖，依類型拆分成不同的小圖
#設定篩選門檻將雜訊過濾掉，使圖表更清晰易讀
df_filtered = df_top_exploded[(df_top_exploded['vote_count'] > 50) & (df_top_exploded['總金額'] > 1000000)]
g = sns.relplot(
    data=df_filtered, 
    x='vote_average', 
    y='總金額', 
    hue='genre_tw',
    col='genre_tw',
    col_wrap=3, #每排顯示3張小圖
    size='vote_count',  
    sizes=(10, 400),
    alpha=0.5,          
    palette='tab10',
    height=4,
    aspect=1.2
)

g.set(yscale='log') #設定Y軸為對數尺度
g.set_axis_labels('TMDB 評分', '總票房 (對數尺度)')
g.set_titles('類型：{col_name}') #設定小圖的標題

g.fig.suptitle('進階氣泡圖：各類型電影的評分、票房與討論熱度拆解', y=1.05, fontsize=16)
plt.show()

# ==========================================
# 圖表3：Pair Plot - 多維度特徵矩陣(使用原始未展開資料)
# ==========================================
#確保每部電影只計算一次，維持統計準確性
pair_df = df[['總金額', '首週票房', 'popularity', 'vote_average']].dropna().copy()
pair_df['總金額_log'] = np.log1p(pair_df['總金額'])
pair_df['首週票房_log'] = np.log1p(pair_df['首週票房'])
pair_df['popularity_log'] = np.log1p(pair_df['popularity'])

threshold = pair_df['總金額'].quantile(0.75)
pair_df['Revenue_Level'] = np.where(pair_df['總金額'] >= threshold, 'Top 25% 高票房', '一般票房')

#隨機抽出800筆資料代表母體
cols_to_plot = ['總金額_log', '首週票房_log', 'vote_average', 'popularity_log', 'Revenue_Level']
plot_df = pair_df[cols_to_plot].sample(n=min(800, len(pair_df)), random_state=42)

sns.pairplot(plot_df, hue='Revenue_Level', corner=True, diag_kind='kde', 
             plot_kws={'alpha': 0.6, 'edgecolor': 'w'}, palette='husl')
plt.suptitle('多維度特徵矩陣 (Pair Plot)：高票房電影具備什麼特徵輪廓', y=1.02)
plt.show()

# ==========================================
# Elbow Method - 尋找最佳 K 值
# ==========================================

pca_df = df.dropna(subset=num_cols).copy()
X = pca_df[num_cols]

scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

sse = []

K_range = range(1, 11)

for k in K_range:
    kmeans = KMeans(
        n_clusters=k,
        random_state=42,
        n_init=10
    )
    kmeans.fit(X_scaled)
    sse.append(kmeans.inertia_)

plt.figure(figsize=(8,5))
plt.plot(K_range, sse, marker='o')
plt.xlabel('群數 K')
plt.ylabel('SSE (Inertia)')
plt.title('Elbow Method：尋找最佳 K 值')
plt.xticks(K_range)
plt.grid(True)
plt.show()

# ==========================================
# 圖表4：PCA 降維視覺化與 K-Means 分群(使用原始未展開資料)
# ==========================================
pca_df = df.dropna(subset=num_cols).copy()
X = pca_df[num_cols]

scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

pca = PCA(n_components=2)
pca_result = pca.fit_transform(X_scaled)
pca_df['PCA1'] = pca_result[:, 0]
pca_df['PCA2'] = pca_result[:, 1]

kmeans = KMeans(n_clusters=3, random_state=42)
pca_df['Cluster'] = kmeans.fit_predict(X_scaled)
pca_df['Cluster_Label'] = pca_df['Cluster'].map({0: '群體 0 (一般電影)', 1: '群體 1 (邊緣長尾)', 2: '群體 2 (商業大片)'})

plt.figure(figsize=(10, 6))
sns.scatterplot(data=pca_df, x='PCA1', y='PCA2', hue='Cluster_Label', palette='Set1', alpha=0.7)
plt.title('PCA 降維視覺化：尋找電影市場的隱藏分群 (K-Means)')
plt.xlabel(f'主成分 1 (PCA1) - 解釋變異: {pca.explained_variance_ratio_[0]:.1%}')
plt.ylabel(f'主成分 2 (PCA2) - 解釋變異: {pca.explained_variance_ratio_[1]:.1%}')
plt.legend(title='演算法分群結果')
plt.tight_layout()
plt.show()