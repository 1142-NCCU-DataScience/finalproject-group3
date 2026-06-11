"""Create exploratory visualizations from data/data.csv."""

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from sklearn.cluster import KMeans
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = PROJECT_ROOT / "data" / "data.csv"
OUTPUT_DIR = PROJECT_ROOT / "results" / "visualizations"

REVENUE_COL = "總金額"
TICKETS_COL = "總票數"
COUNTRY_COL = "國別"
NUMERIC_COLS = [
    REVENUE_COL,
    TICKETS_COL,
    "popularity",
    "vote_average",
    "vote_count",
    "runtime",
]


def save_figure(filename: str) -> None:
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / filename, dpi=200, bbox_inches="tight")
    plt.close()


def load_data() -> pd.DataFrame:
    if not DATA_PATH.exists():
        raise FileNotFoundError(f"Input file not found: {DATA_PATH}")

    data = pd.read_csv(DATA_PATH)
    required = set(NUMERIC_COLS + [COUNTRY_COL, "genres"])
    missing = sorted(required.difference(data.columns))
    if missing:
        raise ValueError(f"Missing required columns: {', '.join(missing)}")

    for column in NUMERIC_COLS:
        data[column] = pd.to_numeric(data[column], errors="coerce")
    return data


def add_genres(data: pd.DataFrame) -> pd.DataFrame:
    exploded = data.assign(
        genre=data["genres"].fillna("Unknown").astype(str).str.split("|")
    ).explode("genre")
    exploded["genre"] = exploded["genre"].str.strip().replace("", "Unknown")
    return exploded


def plot_revenue_by_genre_and_country(data: pd.DataFrame) -> None:
    top_genres = data["genre"].value_counts().nlargest(6).index
    top_countries = data[COUNTRY_COL].value_counts().nlargest(3).index
    plot_data = data[
        data["genre"].isin(top_genres)
        & data[COUNTRY_COL].isin(top_countries)
        & (data[REVENUE_COL] > 0)
    ]

    plt.figure(figsize=(13, 7))
    sns.boxplot(
        data=plot_data,
        x="genre",
        y=REVENUE_COL,
        hue=COUNTRY_COL,
        palette="Set2",
    )
    plt.yscale("log")
    plt.title("Revenue distribution by genre and country")
    plt.xlabel("Genre")
    plt.ylabel("Revenue (log scale)")
    plt.xticks(rotation=30, ha="right")
    save_figure("revenue_by_genre_country.png")


def plot_rating_revenue(data: pd.DataFrame) -> None:
    top_genres = data["genre"].value_counts().nlargest(6).index
    plot_data = data[
        data["genre"].isin(top_genres)
        & (data["vote_count"] > 50)
        & (data[REVENUE_COL] > 1_000_000)
    ]

    chart = sns.relplot(
        data=plot_data,
        x="vote_average",
        y=REVENUE_COL,
        hue="genre",
        col="genre",
        col_wrap=3,
        size="vote_count",
        sizes=(10, 400),
        alpha=0.5,
        palette="tab10",
        height=4,
        aspect=1.2,
    )
    chart.set(yscale="log")
    chart.set_axis_labels("TMDB rating", "Revenue (log scale)")
    chart.set_titles("Genre: {col_name}")
    chart.fig.suptitle("Rating and revenue by genre", y=1.02)
    chart.savefig(OUTPUT_DIR / "rating_revenue_by_genre.png", dpi=200, bbox_inches="tight")
    plt.close(chart.fig)


def plot_pairplot(data: pd.DataFrame) -> None:
    pair_data = data[[REVENUE_COL, TICKETS_COL, "popularity", "vote_average"]].dropna().copy()
    pair_data["log_revenue"] = np.log1p(pair_data[REVENUE_COL].clip(lower=0))
    pair_data["log_tickets"] = np.log1p(pair_data[TICKETS_COL].clip(lower=0))
    pair_data["log_popularity"] = np.log1p(pair_data["popularity"].clip(lower=0))
    threshold = pair_data[REVENUE_COL].quantile(0.75)
    pair_data["revenue_level"] = np.where(
        pair_data[REVENUE_COL] >= threshold, "Top 25%", "Other 75%"
    )

    columns = [
        "log_revenue",
        "log_tickets",
        "vote_average",
        "log_popularity",
        "revenue_level",
    ]
    plot_data = pair_data[columns].sample(n=min(800, len(pair_data)), random_state=42)
    chart = sns.pairplot(
        plot_data,
        hue="revenue_level",
        corner=True,
        diag_kind="hist",
        plot_kws={"alpha": 0.6, "edgecolor": "white"},
        palette="husl",
    )
    chart.fig.suptitle("Relationships among movie performance variables", y=1.02)
    chart.savefig(OUTPUT_DIR / "performance_pairplot.png", dpi=200, bbox_inches="tight")
    plt.close(chart.fig)


def plot_pca_clusters(data: pd.DataFrame) -> None:
    pca_data = data.dropna(subset=NUMERIC_COLS).copy()
    scaled = StandardScaler().fit_transform(pca_data[NUMERIC_COLS])

    pca = PCA(n_components=2)
    components = pca.fit_transform(scaled)
    pca_data["PCA1"] = components[:, 0]
    pca_data["PCA2"] = components[:, 1]
    pca_data["cluster"] = KMeans(n_clusters=3, random_state=42, n_init=10).fit_predict(scaled)

    plt.figure(figsize=(10, 6))
    sns.scatterplot(
        data=pca_data,
        x="PCA1",
        y="PCA2",
        hue="cluster",
        palette="Set1",
        alpha=0.7,
    )
    plt.title("PCA and K-Means clusters")
    plt.xlabel(f"PCA1 ({pca.explained_variance_ratio_[0]:.1%} variance)")
    plt.ylabel(f"PCA2 ({pca.explained_variance_ratio_[1]:.1%} variance)")
    save_figure("pca_kmeans_clusters.png")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sns.set_theme(style="whitegrid")
    data = load_data()
    genre_data = add_genres(data)

    plot_revenue_by_genre_and_country(genre_data)
    plot_rating_revenue(genre_data)
    plot_pairplot(data)
    plot_pca_clusters(data)
    print(f"Done. Visualizations saved to: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
