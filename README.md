# Clinical data pipeline (NHANES)

Portfolio project for end-to-end clinical survey workflows: download public NHANES files, load raw coded tables into PostgreSQL, build a code→label lookup table from CDC codebooks, explore with SQL, and analyze/plot in Python.

## Tech stack

| Layer               | Tools                                                                                                                           |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Data source         | CDC / NCHS [NHANES 2017–2018](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/default.aspx?BeginYear=2017) (file suffix `_J`) |
| Ingest              | **R** (≥ 4.x): `haven` (local `.xpt`), `nhanesA` (`nhanesCodebook`), `stringr`                                                  |
| Database driver (R) | `RPostgreSQL` + `DBI`                                                                                                           |
| Database            | **PostgreSQL 18** (developed against 18.6)                                                                                      |
| Exploration         | SQL under `data/sql/`; `psql` or a Cursor DB client (e.g. DBCode)                                                               |
| Analysis            | **Python 3**: `pandas`, `sqlalchemy`, `psycopg2`, `python-dotenv`, `plotly`, `kaleido` (PDF export), `numpy`                   |
| OS notes            | Windows-friendly; Bash download helper is optional/local                                                                        |

## Pipeline overview

| Stage    | What runs                          | Output                                                            |
| -------- | ---------------------------------- | ----------------------------------------------------------------- |
| Download | Local sync helper (gitignored)     | `.xpt` files in `data/raw/nhanes/2017-2018/`                      |
| Document | `_file_list.txt`                   | Human-readable form → question → code reference                   |
| Load     | `data/ingest/write_tables_to_DB.R` | One Postgres table per XPT **with raw numeric/text codes**        |
| Codebook | Same script (`nhanesCodebook`)     | Postgres `codebook` (`form`, `variable`, `code`, `meaning`)       |
| Query    | `data/sql/*.sql`                   | Psych / diet / lab / covariate analysis extracts (unweighted)     |
| Analyze  | `python main.py`                   | Plotly figures under `data/static/figures/`                       |

Tables join on `SEQN` (respondent ID). Survey tables keep **codes** (e.g. `0`, `1`, `3`). Human-readable labels live in `codebook` and are joined when needed.

## Repository layout

```
main.py                               # Entry point (DataPlotter methods)
data/
  ingest/
    write_tables_to_DB.R              # Load XPTs + build/write codebook
  sql/
    demo.sql                          # Small exploratory example
    subset_for_psych_and_diet_metrics.sql
    subset_for_psych_diet_physiological_metrics_with_covariates.sql
  raw/nhanes/2017-2018/               # Local XPTs + _file_list.txt
  processed/                          # Intermediate outputs (gitignored)
  static/figures/                     # Plotly HTML/PDF exports
src/
  __init__.py
  consume/
    __init__.py
    df_loader.py                      # .env + SQLAlchemy engine + project root
    data_plotter.py                   # Analysis / Plotly figures
tests/
.Renviron                             # DB credentials for R (gitignored)
.env                                  # DB credentials for Python (gitignored)
```

Raw XPTs, secrets, and local notebooks (`notebook.ipynb`) are not committed.

## Requirements

- **R** ≥ 4.x — `haven`, `nhanesA`, `stringr`, `RPostgreSQL`, `DBI`
- **PostgreSQL 18** (default port **5432**; developed against **18.6**)
- **Python 3** — `pandas`, `sqlalchemy`, `psycopg2-binary`, `python-dotenv`, `plotly`, `kaleido`, `numpy`
- Network access to `wwwn.cdc.gov` during codebook load
- Optional: Bash + `curl` (or WSL) for the local sync script

## Database setup

### 1. Install and start PostgreSQL 18

Listening on **5432** (or set `DB_PORT`).

### 2. Create role and database

```sql
CREATE ROLE your_user LOGIN PASSWORD 'your_password' SUPERUSER;
CREATE DATABASE "NHANES_2017-2018" OWNER your_user;
```

### 3. Set credentials

**R** — `.Renviron` in the project root:

```
DB_USER=your_user
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432
```

Database name is set in R (`dbname = "NHANES_2017-2018"`), not in `.Renviron`.

**Python** — `.env` in the project root:

```
DB_USER=your_user
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432
DB_NAME=NHANES_2017-2018
```

Never commit `.Renviron` or `.env`.

### 4–5. Install packages

```r
install.packages(c("haven", "nhanesA", "stringr", "RPostgreSQL", "DBI"))
```

```powershell
pip install pandas sqlalchemy psycopg2-binary python-dotenv plotly kaleido numpy
```

## Usage

Always run from the **project root** so `.env`, `.Renviron`, and `src.*` imports resolve.

### Load survey tables + codebook

```r
source("data/ingest/write_tables_to_DB.R")
```

1. Connect with `.Renviron`.
2. Read each local `.xpt` with `haven::read_xpt` (raw codes).
3. Call `nhanesA::nhanesCodebook` per file (`tryCatch`).
4. Write one Postgres table per questionnaire + flattened **`codebook`**.

| Column     | Content                                   |
| ---------- | ----------------------------------------- |
| `form`     | e.g. `DPQ_J`                              |
| `variable` | e.g. `DPQ010`                             |
| `code`     | Stored survey value (e.g. `0`, `1`, `7`)  |
| `meaning`  | CDC label (e.g. `Not at all`)             |

### SQL extracts

Quote mixed-case names (`"DPQ_J"`, `"SEQN"`). Filter on **codes** unless joining `codebook`.

| File | Role |
| ---- | ---- |
| `subset_for_psych_and_diet_metrics.sql` | Slim DEMO ⋈ DPQ + diet / BMI / smoking (EDA: BMI vs sugar) |
| `subset_for_psych_diet_physiological_metrics_with_covariates.sql` | Main analysis extract: PHQ-9 items, labs, BP, diet, PA, smoking, alcohol, comorbidities |
| `demo.sql` | Tiny exploratory example |

Both analysis extracts are **unweighted** (no `WTMEC2YR` / fasting subsample weights). Adults only (`RIDAGEYR >= 18`).

Avoid bare `%` in SQL comments when using `pd.read_sql` + psycopg2 (`%` is treated as a bind placeholder). Prefer `text(sql)` + a connection, or write “percent” in comments.

### Python analysis

```powershell
python main.py
```

`main.py` constructs `DataPlotter` (`DfLoader` opens the DB) and calls the active method.

| Method | Status / intent |
| ------ | --------------- |
| `plot_bmi_vs_mean_sugar_intake_by_age_group` | Working EDA: Plotly column of age panels, BMI vs 2-day mean sugar, OLS + Pearson `r` |
| `plot_forest_effect_sizes_of_phys_markers_on_phq_9` | In progress: PHQ-9 scoring + adjusted associations of physiological markers → forest plot |

#### Analysis targets (forest plot)

**Outcome:** PHQ-9 total from `DPQ010`–`DPQ090` (valid codes 0–3; `DPQ100` is impairment, not in the sum).

**Exposures (by group for colored forest facets):**

| Group | Variables |
| ----- | --------- |
| Metabolic | `LBXGLU`, `LBXIN`, `LBXGH`, `LBXTR`, `LBDLDL`, `LBXTC`, `LBDHDD` |
| Vascular | mean `BPXSY1–3`, mean `BPXDI1–3`, `BMXBMI`, `BMXWAIST` |
| Hepatic | `LBXSATSI` (ALT), `LBXSGTSI` (GGT) |
| Inflammatory | `LBXHSCRP` |
| Renal | `LBXSCR`, `LBXSBU`, `LBXSUA` |
| Iron | `LBXFER`, `LBXIRN`, `LBDPCT`, `LBXTFR` |

**Core covariates (adjustment / sensitivity):** age, sex, race/ethnicity, education, PIR, diet energy/sugar, activity (`PAQ*`), smoking (`SMQ*` / `LBXCOT`), alcohol (`ALQ*`), sleep, diabetes/BP/chol history, selected `MCQ*` comorbidities; `PHAFSTHR` for fasting lab context.

Public 2017–2018 NHANES does **not** include most molecular markers from broader depression–metabolism literature (ceramides, HRV, cytokines, etc.). Only analytes present in the local XPTs are used.

### Human-readable reference

`data/raw/nhanes/2017-2018/_file_list.txt` — Ctrl+F codebook. Live SQL labels: Postgres **`codebook`**.

## Data notes

- Public-use NHANES only; join key `SEQN`.
- Some tables have multiple rows per `SEQN`.
- Adult PHQ-9 is public (`DPQ_J`); youth PHQ is RDC-only.
- Labs are **cross-sectional** (one MEC visit). BP has same-visit repeats; diet has up to two recalls — not longitudinal biomarker repeats.
- Framing: **unweighted sample** (“among respondents with available data”), not US population inference, until weights are designed in.
- Do not commit `.Renviron`, `.env`, or raw clinical extracts.

## Status

- Download + local XPT cache: in place
- `_file_list.txt` + Postgres load + `codebook`: implemented
- SQL: diet/psych subset + expanded phys/covariate subset
- Python package layout (`src.consume`, `main.py`): in place
- BMI vs 2-day mean sugar (Plotly): implemented
- PHQ-9 scoring + marker effect sizes / forest plot: in progress
- Formal schema / survey weighting: not finalized
