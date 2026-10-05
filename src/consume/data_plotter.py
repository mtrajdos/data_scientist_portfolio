import os
from pathlib import Path

import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from dotenv import load_dotenv
from plotly.subplots import make_subplots
from sqlalchemy import create_engine

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / ".env")

engine = create_engine(
    "postgresql+psycopg2://{user}:{password}@{host}:{port}/{dbname}".format(
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        host=os.environ["DB_HOST"],
        port=os.environ["DB_PORT"],
        dbname=os.environ["DB_NAME"],
    )
)

sql = (ROOT / "data/sql/subset_for_psych_and_diet_metrics.sql").read_text(
    encoding="utf-8"
)
df = pd.read_sql(sql, engine)

# Plot BMI vs mean sugar intake (average of Day 1 and Day 2 recalls when both exist):
# - one subplot per age group (single column so axes line up)
# - one color + regression line per subplot
# - show Pearson r on each subplot
age_labels = ["18-24", "25-34", "35-44", "45-54", "55-64", "65-74", "75+"]
df = df.copy()

# Bin ages into labeled groups (include_lowest so age 18 is kept in 18-24)
df["age_group"] = pd.cut(
    df["RIDAGEYR"],
    bins=[18, 24, 34, 44, 54, 64, 74, 100],
    labels=age_labels,
    include_lowest=True,
)

# 2-day mean sugar (g): only when both DR1 and DR2 are non-missing (skipna=False)
df["TSUGR_mean"] = df[["DR1TSUGR", "DR2TSUGR"]].mean(axis=1, skipna=False)

# One distinct color per age group
palette = px.colors.qualitative.Plotly

# Stacked column of subplots; shared axes so BMI/sugar ticks align and scales match
fig = make_subplots(
    rows=len(age_labels),
    cols=1,
    shared_xaxes=True,
    shared_yaxes=True,
    subplot_titles=[f"Age {label}" for label in age_labels],
    vertical_spacing=0.07,
)

for i, age_label in enumerate(age_labels):
    row = i + 1
    color = palette[i % len(palette)]
    # Subset to rows in this age bracket that have both BMI and 2-day mean sugar
    plot_df = df.loc[df["age_group"] == age_label, ["BMXBMI", "TSUGR_mean"]].dropna()

    if plot_df.empty:
        note = "n=0"
    else:
        # Scatter: BMI (x) vs mean sugar (y)
        fig.add_trace(
            go.Scatter(
                x=plot_df["BMXBMI"],
                y=plot_df["TSUGR_mean"],
                mode="markers",
                marker={"size": 4, "color": color, "opacity": 0.65},
                name=age_label,
                showlegend=False,
                hovertemplate="BMI=%{x:.1f}<br>Sugar=%{y:.1f}g<extra></extra>",
            ),
            row=row,
            col=1,
        )
        if len(plot_df) >= 2:
            # Pearson correlation and OLS line (sugar ~ BMI) for this age band
            r = plot_df["BMXBMI"].corr(plot_df["TSUGR_mean"])
            coeffs = np.polyfit(plot_df["BMXBMI"], plot_df["TSUGR_mean"], deg=1)
            x_line = np.linspace(plot_df["BMXBMI"].min(), plot_df["BMXBMI"].max(), 100)
            y_line = coeffs[0] * x_line + coeffs[1]
            fig.add_trace(
                go.Scatter(
                    x=x_line,
                    y=y_line,
                    mode="lines",
                    line={"color": color, "width": 2},
                    showlegend=False,
                    hoverinfo="skip",
                ),
                row=row,
                col=1,
            )
            note = f"r={r:.2f} (n={len(plot_df)})"
        else:
            note = f"n={len(plot_df)}"

    # Annotation: correlation and sample size for this subplot
    fig.add_annotation(
        text=note,
        xref="x domain",
        yref="y domain",
        x=0.02,
        y=0.98,
        xanchor="left",
        yanchor="top",
        showarrow=False,
        font={"size": 11, "family": "Courier New, monospace"},
        bgcolor="rgba(255,255,255,0.75)",
        row=row,
        col=1,
    )

# X-axis on every panel (shared_xaxes hides upper tick labels by default)
for row in range(1, len(age_labels) + 1):
    fig.update_xaxes(
        title_text="BMI",
        showticklabels=True,
        ticks="outside",
        ticklabelstandoff=5,
        title_standoff=5,
        row=row,
        col=1,
    )
fig.update_yaxes(title_text="Mean sugar (g)", range=[0, 600], tickvals=[0, 200, 400, 600])
fig.update_layout(
    title="BMI vs 2-Day Mean Sugar Intake by Age Group",
    height=2000,
    width=1000,
    template="plotly_white"
)

# Save HTML (interactive) and PDF (static); PDF needs the kaleido package
out_dir = ROOT / "data/static/figures"
out_dir.mkdir(parents=True, exist_ok=True)
fig.write_html(out_dir / "bmi_sugar_intake.html")
try:
    fig.write_image(out_dir / "bmi_sugar_intake.pdf", format="pdf")
except (ValueError, ImportError, RuntimeError) as exc:
    print(f"PDF export skipped ({exc}). Install kaleido for PDF: pip install kaleido")

fig.show()
