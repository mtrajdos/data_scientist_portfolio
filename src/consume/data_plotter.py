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
        # Load data
        self.data_sql = (
            self.project_root
            / "data/sql/subset_for_psych_diet_physiological_metrics_with_covariates.sql"
        ).read_text(encoding="utf-8")
        self.df = pd.read_sql(text(self.data_sql), self.df_loader.engine)
        df = self.df.copy()

        # Load label data
        self.label_sql = (
            self.project_root / "data/sql/nhanes_var_labels.sql"
        ).read_text(encoding="utf-8")
        self.labels = pd.read_sql(text(self.label_sql), self.df_loader.engine)
        labels = self.labels.copy()
        # NHANES code -> short axis title (falls back to code if missing)
        label_map = dict(zip(labels["code"], labels["short_label"]))

        age_labels = ["18-24", "25-34", "35-44", "45-54", "55-64", "65-74", "75+"]

        # Bin ages into labeled groups (include_lowest so age 18 is kept in 18-24)
        df["age_group"] = pd.cut(
            df["RIDAGEYR"],
            bins=[18, 24, 34, 44, 54, 64, 74, 100],
            labels=age_labels,
            include_lowest=True,
        )

        # Define covariates
        covariates = [
            "RIAGENDR",
            "INDFMPIR",
            "SMQ020",
            "SMQ040",
            "LBXCOT",
            "ALQ121",
            "BMXBMI",
        ]

        # Define predictors (BP uses mean of available readings; BMI is a covariate only)
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
            "vascular": [
                "BPXSY",
                "BPXDI",
            ],
            "hepatic": ["LBXSATSI", "LBXSGTSI"],
            "inflammatory": ["LBXHSCRP"],
            "renal": ["LBXSCR", "LBXSBU", "LBXSUA"],
            "iron": ["LBXFER", "LBXIRN", "LBDPCT", "LBXTFR"],
        }

        # Mean BP across available readings (skipna so 1–4 measures can contribute)
        df["BPXSY"] = df[["BPXSY1", "BPXSY2", "BPXSY3", "BPXSY4"]].mean(
            axis=1, skipna=True
        )
        df["BPXDI"] = df[["BPXDI1", "BPXDI2", "BPXDI3", "BPXDI4"]].mean(
            axis=1, skipna=True
        )

        # Define DPQ_J items
        dpq_j_items = [f"DPQ0{i}0" for i in range(1, 10)]

        # Create DPQ_J total column
        df["DPQ_J_total"] = 0

        # Create a placeholder for forest plot data
        fp_data = []

        # Calculate DPQ_J scores
        for item in dpq_j_items:
            # same length as df: keep 0–3, otherwise use 0
            valid = df[item].where(df[item].isin([0, 1, 2, 3]), other=0)
            df["DPQ_J_total"] += valid

        # Fixed y-axis order across age plots (category → predictor list order)
        predictor_order = [p for plist in predictors.values() for p in plist]

        # Calculate effect size for each predictor in each age group
        for category, predictor_list in predictors.items():
            print(f"--- Processing {category} domain ---")

            for predictor in predictor_list:
                print(f"Analyzing predictor: {predictor}")

                for age in df["age_group"].dropna().unique():
                    # Subset: no NAs in predictor, outcome, or covariates
                    sub_df = df[df["age_group"] == age].dropna(
                        subset=[predictor, "DPQ_J_total"] + covariates
                    )

                    formula = f"DPQ_J_total ~ {predictor} + " + " + ".join(covariates)
                    model = smf.ols(formula=formula, data=sub_df).fit()

                    effect_size = model.params[predictor]
                    p_value = model.pvalues[predictor]
                    std_err = model.bse[predictor]
                    conf_int = model.conf_int().loc[predictor]
                    ci_lower = conf_int[0]
                    ci_upper = conf_int[1]

                    fp_data.append(
                        {
                            "category": category,
                            "predictor": predictor,
                            "age_group": age,
                            "effect_size": effect_size,
                            "std_err": std_err,
                            "ci_lower": ci_lower,
                            "ci_upper": ci_upper,
                            "p_value": p_value,
                            "sample_size": len(sub_df),
                        }
                    )

        fp_df = pd.DataFrame(fp_data)
        fp_df["predictor_label"] = (
            fp_df["predictor"].map(label_map).fillna(fp_df["predictor"])
        )
        # Singular / tiny-n fits yield inf SE and NaN CIs — drop from plots
        fp_df["ci_ok"] = (
            np.isfinite(fp_df["std_err"])
            & np.isfinite(fp_df["ci_lower"])
            & np.isfinite(fp_df["ci_upper"])
        )
        fp_df = fp_df.loc[fp_df["ci_ok"]].copy()
        # Significant if 95% CI excludes 0 (equiv. to two-sided p < 0.05 for OLS)
        fp_df["significant"] = (fp_df["ci_lower"] > 0) | (fp_df["ci_upper"] < 0)

        def _fmt_estimate(row: pd.Series) -> str:
            # Fixed-width monospaced fields so '-' stays in one vertical column
            return (
                f"{row['effect_size']:>8.3f} "
                f"({row['ci_lower']:>8.3f}, {row['ci_upper']:>8.3f})"
            )

        fp_df["estimate_text"] = fp_df.apply(_fmt_estimate, axis=1)
        mono = {"size": 11, "family": "Courier New, monospace"}
        color_sig = "#1f77b4"
        color_ns = "#b0b7c3"  # faded grey-blue for non-significant

        for age_group in age_labels:
            age_df = fp_df[fp_df["age_group"] == age_group].copy()
            if age_df.empty:
                print(f"No stable estimates for age {age_group}; skipping plot.")
                continue
            # Same predictor order on every age panel
            age_df["predictor"] = pd.Categorical(
                age_df["predictor"], categories=predictor_order, ordered=True
            )
            age_df = age_df.sort_values("predictor").reset_index(drop=True)
            y_labels = age_df["predictor_label"].astype(str)
            y_pos = list(range(len(age_df)))

            # Per-age x-range: always fit full error bars (+ small pad)
            lo = float(age_df["ci_lower"].min())
            hi = float(age_df["ci_upper"].max())
            pad = 0.05 * (hi - lo if hi > lo else 1.0)
            x_range = [lo - pad, hi + pad]

            # 3 columns: right-justified names | forest | left-justified estimates
            fig = make_subplots(
                rows=1,
                cols=3,
                column_widths=[0.28, 0.42, 0.30],
                shared_yaxes=True,
                horizontal_spacing=0.02,
            )

            # Anchor at x=1 with text to the left → right-justified against the forest
            fig.add_trace(
                go.Scatter(
                    x=np.ones(len(age_df)),
                    y=y_pos,
                    mode="text",
                    text=y_labels,
                    textposition="middle left",
                    textfont=mono,
                    hoverinfo="skip",
                    showlegend=False,
                ),
                row=1,
                col=1,
            )

            def _add_forest_points(mask: pd.Series, color: str) -> None:
                if not mask.any():
                    return
                sub = age_df.loc[mask]
                fig.add_trace(
                    go.Scatter(
                        x=sub["effect_size"],
                        y=sub.index.to_list(),
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
                        hovertemplate=(
                            "%{customdata[1]}<br>β=%{x:.3f}<br>n=%{customdata[0]}"
                            "<extra></extra>"
                        ),
                        customdata=np.column_stack(
                            [
                                sub["sample_size"],
                                sub["predictor_label"].astype(str).to_numpy(),
                            ]
                        ),
                        showlegend=False,
                    ),
                    row=1,
                    col=2,
                )

            _add_forest_points(~age_df["significant"], color_ns)
            _add_forest_points(age_df["significant"], color_sig)

            # Left-justified monospaced block; fixed widths keep '-' aligned
            fig.add_trace(
                go.Scatter(
                    x=np.zeros(len(age_df)),
                    y=y_pos,
                    mode="text",
                    text=age_df["estimate_text"],
                    textposition="middle right",
                    textfont=mono,
                    hoverinfo="skip",
                    showlegend=False,
                ),
                row=1,
                col=3,
            )
            # Same anchor/font as values; pad to estimate width so title is centered over them
            est_width = len(age_df["estimate_text"].iloc[0])
            header = "Estimate (95% CI)".center(est_width)
            fig.add_trace(
                go.Scatter(
                    x=[0],
                    y=[-1.15],
                    mode="text",
                    text=[header],
                    textposition="middle right",
                    textfont={**mono, "size": 12},
                    hoverinfo="skip",
                    showlegend=False,
                ),
                row=1,
                col=3,
            )

            fig.update_xaxes(
                visible=False,
                range=[0, 1.02],
                row=1,
                col=1,
            )
            fig.update_xaxes(
                title_text="Effect size (Δ PHQ-9 per 1-unit predictor)",
                showgrid=False,
                zeroline=True,
                zerolinecolor="black",
                zerolinewidth=1,
                range=x_range,
                row=1,
                col=2,
            )
            fig.update_xaxes(
                visible=False,
                range=[-0.02, 1.55],
                row=1,
                col=3,
            )
            for col in (1, 2, 3):
                fig.update_yaxes(
                    visible=False,
                    range=[len(age_df) - 0.5, -1.6],
                    row=1,
                    col=col,
                )

            fig.update_layout(
                title={
                    "text": f"Physiological marker effects on PHQ-9 — age {age_group}",
                    "x": 0.5,
                    "xanchor": "center",
                },
                template="plotly_white",
                font=mono,
                height=max(520, 24 * len(age_df) + 140),
                width=1150,
                margin={"l": 40, "r": 40, "t": 70, "b": 70},
            )

            out_dir = self.project_root / "data/static/figures"
            out_dir.mkdir(parents=True, exist_ok=True)
            try:
                fig.write_image(
                    out_dir / f"marker_effect_size_{age_group}.pdf", format="pdf"
                )
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
