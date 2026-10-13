import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import statsmodels.formula.api as smf
from plotly.subplots import make_subplots
from sqlalchemy import text

from src.consume.df_loader import DfLoader


class DataPlotter:
    def __init__(self):
        self.df_loader = DfLoader()
        self.project_root = self.df_loader.project_root

    # RQ: What are the effects of physiological markers (cardiometabolic, renal, etc.)
    # on depression severity defined by DPQ_J total score?
    def plot_forest_effect_sizes_of_phys_markers_on_phq_9(self):
        df = pd.read_sql(
            text(
                (
                    self.project_root
                    / "data/sql/subset_for_psych_diet_physiological_metrics_with_covariates.sql"
                ).read_text(encoding="utf-8")
            ),
            self.df_loader.engine,
        )
        labels = pd.read_sql(
            text(
                (self.project_root / "data/sql/nhanes_var_labels.sql").read_text(
                    encoding="utf-8"
                )
            ),
            self.df_loader.engine,
        )
        label_map = dict(zip(labels["code"], labels["short_label"]))

        age_labels = ["18-24", "25-34", "35-44", "45-54", "55-64", "65-74", "75+"]
        df["age_group"] = pd.cut(
            df["RIDAGEYR"],
            bins=[18, 24, 34, 44, 54, 64, 74, 100],
            labels=age_labels,
            include_lowest=True,
        )

        covariates = [
            "RIAGENDR",
            "INDFMPIR",
            "SMQ020",
            "SMQ040",
            "LBXCOT",
            "ALQ121",
            "BMXBMI",
        ]
        predictors = {
            "metabolic": [
                "LBXGLU",
                "LBXSGL",
                "LBXIN",
                "LBXGH",
                "LBXTR",
                "LBDLDL",
                "LBXTC",
                "LBDHDD",
            ],
            "vascular": ["BPXSY", "BPXDI"],
            "hepatic": ["LBXSATSI", "LBXSGTSI"],
            "inflammatory": ["LBXHSCRP"],
            "renal": ["LBXSCR", "LBXSBU", "LBXSUA"],
            "iron": ["LBXFER", "LBXIRN", "LBDPCT", "LBXTFR"],
        }
        predictor_order = [p for group in predictors.values() for p in group]

        df["BPXSY"] = df[["BPXSY1", "BPXSY2", "BPXSY3", "BPXSY4"]].mean(
            axis=1, skipna=True
        )
        df["BPXDI"] = df[["BPXDI1", "BPXDI2", "BPXDI3", "BPXDI4"]].mean(
            axis=1, skipna=True
        )
        df["DPQ_J_total"] = 0
        for item in [f"DPQ0{i}0" for i in range(1, 10)]:
            df["DPQ_J_total"] += df[item].where(df[item].isin([0, 1, 2, 3]), other=0)

        # OLS per marker × age; keep finite CIs only
        rows = []
        for category, marker_list in predictors.items():
            for marker in marker_list:
                for age in age_labels:
                    sub = df.loc[df["age_group"] == age].dropna(
                        subset=[marker, "DPQ_J_total", *covariates]
                    )
                    model = smf.ols(
                        f"DPQ_J_total ~ {marker} + {' + '.join(covariates)}",
                        data=sub,
                    ).fit()
                    ci = model.conf_int().loc[marker]
                    rows.append(
                        {
                            "category": category,
                            "predictor": marker,
                            "age_group": age,
                            "effect_size": model.params[marker],
                            "std_err": model.bse[marker],
                            "ci_lower": ci[0],
                            "ci_upper": ci[1],
                            "p_value": model.pvalues[marker],
                            "sample_size": len(sub),
                        }
                    )

        fp = pd.DataFrame(rows)
        fp["predictor_label"] = fp["predictor"].map(label_map).fillna(fp["predictor"])
        fp = fp[
            np.isfinite(fp["std_err"])
            & np.isfinite(fp["ci_lower"])
            & np.isfinite(fp["ci_upper"])
        ].copy()
        fp["significant"] = (fp["ci_lower"] > 0) | (fp["ci_upper"] < 0)

        mono = {"size": 11, "family": "Courier New, monospace"}
        colors = {True: "#1f77b4", False: "#b0b7c3"}
        out_dir = self.project_root / "data/static/figures"
        out_dir.mkdir(parents=True, exist_ok=True)

        for age in age_labels:
            age_df = (
                fp.loc[fp["age_group"] == age]
                .assign(
                    predictor=lambda d: pd.Categorical(
                        d["predictor"], categories=predictor_order, ordered=True
                    )
                )
                .sort_values("predictor")
                .reset_index(drop=True)
            )
            if age_df.empty:
                print(f"No stable estimates for age {age}; skipping plot.")
                continue

            lo, hi = age_df["ci_lower"].min(), age_df["ci_upper"].max()
            pad = 0.05 * ((hi - lo) if hi > lo else 1.0)

            fig = go.Figure()
            # Non-sig first, then sig so blue draws on top
            for is_sig, color in ((False, colors[False]), (True, colors[True])):
                sub = age_df.loc[age_df["significant"] == is_sig]
                if sub.empty:
                    continue
                fig.add_trace(
                    go.Scatter(
                        x=sub["effect_size"],
                        y=sub["predictor_label"],
                        mode="markers",
                        marker={"size": 9, "color": color, "opacity": 0.9},
                        error_x={
                            "type": "data",
                            "symmetric": False,
                            "array": sub["ci_upper"] - sub["effect_size"],
                            "arrayminus": sub["effect_size"] - sub["ci_lower"],
                            "width": 2,
                            "color": color,
                        },
                        customdata=np.column_stack(
                            [
                                sub["sample_size"],
                                sub["ci_lower"],
                                sub["ci_upper"],
                            ]
                        ),
                        hovertemplate=(
                            "%{y}<br>"
                            "β=%{x:.3f} (%{customdata[1]:.3f}, %{customdata[2]:.3f})"
                            "<br>n=%{customdata[0]}<extra></extra>"
                        ),
                        showlegend=False,
                    )
                )

            fig.update_yaxes(
                categoryorder="array",
                categoryarray=age_df["predictor_label"].tolist()[::-1],
                automargin=True,
                showgrid=False,
                ticklabelposition="outside left",
                tickfont=mono,
            )
            fig.update_xaxes(
                title_text="Effect size (Δ PHQ-9 per 1-unit predictor)",
                showgrid=False,
                zeroline=True,
                zerolinecolor="black",
                zerolinewidth=1,
                range=[lo - pad, hi + pad],
            )
            fig.update_layout(
                title={
                    "text": f"Physiological marker effects on PHQ-9 — age {age}",
                    "x": 0.5,
                    "xanchor": "center",
                },
                template="plotly_white",
                font=mono,
                height=max(480, 28 * len(age_df) + 120),
                width=900,
                margin={"l": 40, "r": 40, "t": 70, "b": 70},
            )

            try:
                fig.write_image(out_dir / f"marker_effect_size_{age}.pdf", format="pdf")
            except (ValueError, ImportError, RuntimeError) as exc:
                print(
                    f"PDF export skipped ({exc}). Install kaleido for PDF: pip install kaleido"
                )
            fig.show()

    # RQ: Accounting for age groups, is there an association between BMI and
    # mean sugar intake over 2 days?
    def plot_bmi_vs_mean_sugar_intake_by_age_group(self):
        self.data_sql = (
            self.project_root / "data/sql/subset_for_psych_and_diet_metrics.sql"
        ).read_text(encoding="utf-8")
        self.df = pd.read_sql(text(self.data_sql), self.df_loader.engine)
        df = self.df.copy()

        # Plot BMI vs mean sugar intake (average of Day 1 and Day 2 recalls when both exist):
        # - one subplot per age group (single column so axes line up)
        # - one color + regression line per subplot
        # - show Pearson r on each subplot
        age_labels = ["18-24", "25-34", "35-44", "45-54", "55-64", "65-74", "75+"]

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
            plot_df = df.loc[
                df["age_group"] == age_label, ["BMXBMI", "TSUGR_mean"]
            ].dropna()

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
                    x_line = np.linspace(
                        plot_df["BMXBMI"].min(), plot_df["BMXBMI"].max(), 100
                    )
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
        fig.update_yaxes(
            title_text="Mean sugar (g)", range=[0, 600], tickvals=[0, 200, 400, 600]
        )
        fig.update_layout(
            title="BMI vs 2-Day Mean Sugar Intake by Age Group",
            height=2000,
            width=1000,
            template="plotly_white",
        )

        # Save PDF
        out_dir = self.project_root / "data/static/figures"
        out_dir.mkdir(parents=True, exist_ok=True)
        try:
            fig.write_image(out_dir / "bmi_sugar_intake.pdf", format="pdf")
        except (ValueError, ImportError, RuntimeError) as exc:
            print(
                f"PDF export skipped ({exc}). Install kaleido for PDF: pip install kaleido"
            )

        fig.show()
