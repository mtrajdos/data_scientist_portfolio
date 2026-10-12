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
| Analysis            | **Python 3**: `pandas`, `sqlalchemy`, `psycopg2`, `python-dotenv`, `statsmodels`, `plotly`, `kaleido` (PDF export), `numpy`  |
| OS notes            | Windows-friendly; Bash download helper is optional/local                                                                        |

## Pipeline overview

| Stage    | What runs                          | Output                                                            |
| -------- | ---------------------------------- | ----------------------------------------------------------------- |
| Download | Local sync helper (gitignored)     | `.xpt` files in `data/raw/nhanes/2017-2018/`                      |
| Document | `_file_list.txt`                   | Human-readable form → question → code reference                   |
| Load     | `data/ingest/write_tables_to_DB.R` | One Postgres table per XPT **with raw numeric/text codes**        |
| Codebook | Same script (`nhanesCodebook`)     | Postgres `codebook` (`form`, `variable`, `code`, `meaning`)       |
| Query    | `data/sql/*.sql`                   | Psych / diet / lab / covariate analysis extracts (unweighted)     |
| Analyze  | `python main.py`                   | Age-stratified forest PDFs under `data/static/figures/`           |

Tables join on `SEQN` (respondent ID). Survey tables keep **codes** (e.g. `0`, `1`, `3`). Human-readable labels live in `codebook` and are joined when needed.

## Repository layout

```
main.py                               # Entry point (DataPlotter methods)
data/
  ingest/
    write_tables_to_DB.R              # Load XPTs + build/write codebook
  sql/
    demo.sql                          # Small exploratory example
    nhanes_var_labels.sql             # Code → short axis / legend titles
    subset_for_psych_and_diet_metrics.sql
    subset_for_psych_diet_physiological_metrics_with_covariates.sql
  raw/nhanes/2017-2018/               # Local XPTs + _file_list.txt
  processed/                          # Intermediate outputs (gitignored)
  static/figures/                     # Plotly PDF exports (e.g. marker_effect_size_*.pdf)
src/
  __init__.py
  consume/
    __init__.py
    df_loader.py                      # .env + SQLAlchemy engine + project root
    data_plotter.py                   # OLS + Plotly forest / EDA figures
tests/
.Renviron                             # DB credentials for R (gitignored)
.env                                  # DB credentials for Python (gitignored)
```
## Requirements

- **R** ≥ 4.x — `haven`, `nhanesA`, `stringr`, `RPostgreSQL`, `DBI`
- **PostgreSQL 18** (default port **5432**; developed against **18.6**)
- **Python 3** — `pandas`, `sqlalchemy`, `psycopg2-binary`, `python-dotenv`, `statsmodels`, `plotly`, `kaleido`, `numpy`
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

### 4–5. Install packages

```r
install.packages(c("haven", "nhanesA", "stringr", "RPostgreSQL", "DBI"))
```

```powershell
pip install pandas sqlalchemy psycopg2-binary python-dotenv statsmodels plotly kaleido numpy
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
| `subset_for_psych_diet_physiological_metrics_with_covariates.sql` | Main analysis extract: PHQ-9 items, labs, BP, diet, smoking, alcohol, comorbidities |
| `nhanes_var_labels.sql` | Plot axis titles: `code` → `short_label` (from `_file_list.txt`, lightly shortened) |
| `demo.sql` | Tiny exploratory example |

Both analysis extracts are **unweighted** (no `WTMEC2YR` / fasting subsample weights). Adults only (`RIDAGEYR >= 18`).

### Python analysis

```powershell
python main.py
```

`main.py` constructs `DataPlotter` (`DfLoader` opens the DB) and calls the active method.

| Method | Status / intent |
| ------ | --------------- |
| `plot_forest_effect_sizes_of_phys_markers_on_phq_9` | age-stratified OLS forest plots (marker → PHQ-9), PDF per age band |
| `plot_bmi_vs_mean_sugar_intake_by_age_group` | Plotly column of age panels, BMI vs 2-day mean sugar, OLS + Pearson `r` |