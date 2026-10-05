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
| Analysis            | **Python 3**: `pandas`, `sqlalchemy`, `psycopg2`, `python-dotenv`, `plotly`, `kaleido` (PDF export)                            |
| OS notes            | Windows-friendly; Bash download helper is optional/local                                                                        |

## Pipeline overview

| Stage    | What runs                                        | Output                                                     |
| -------- | ------------------------------------------------ | ---------------------------------------------------------- |
| Download | Local sync helper (gitignored)                   | `.xpt` files in `data/raw/nhanes/2017-2018/`               |
| Document | `data/raw/nhanes/2017-2018/_file_list.txt`       | Human-readable form → question → code reference            |
| Load     | `data/ingest/write_tables_to_DB.R`               | One Postgres table per XPT **with raw numeric/text codes** |
| Codebook | Same script (`nhanesCodebook` → flatten)         | Postgres table `codebook` (`form`, `variable`, `code`, `meaning`)  |
| Query    | `data/sql/*.sql`                                 | Joins for psych / diet / anthropometry subsets             |
| Analyze  | `src/consume/data_plotter.py`                    | Interactive HTML + PDF figures under `data/static/figures/` |

Tables join on `SEQN` (respondent ID). Survey tables keep **codes** (e.g. `0`, `1`, `3`). Human-readable labels live in the separate `codebook` table and are joined when needed.

## Repository layout

```
data/
  ingest/
    write_tables_to_DB.R              # Load XPTs + build/write codebook
  sql/
    demo.sql                          # Small exploratory example
    subset_for_psych_and_diet_metrics.sql  # DEMO + DPQ + diet/behavior join
  queried/                            # Placeholder for query exports
  raw/nhanes/2017-2018/               # Local XPTs + _file_list.txt
  processed/                          # Intermediate outputs (gitignored)
  static/figures/                     # Plotly HTML/PDF exports
src/
  consume/
    data_plotter.py                   # Pull SQL subset; BMI vs sugar by age (Plotly)
tests/
.Renviron                             # DB credentials for R (gitignored)
.env                                  # DB credentials for Python (gitignored)
```

Raw XPTs and secrets are not committed. Environment-specific helpers such as the NHANES sync script stay local via `.gitignore`.

## Requirements

- **R** ≥ 4.x  
  Packages: `haven`, `nhanesA`, `stringr`, `RPostgreSQL`, `DBI`
- **PostgreSQL 18** (server running; default port **5432**)  
  Developed/tested with **PostgreSQL 18.6**
- **Python 3**  
  Packages: `pandas`, `sqlalchemy`, `psycopg2-binary`, `python-dotenv`, `plotly`, `kaleido`, `numpy`
- Network access to `wwwn.cdc.gov` (required for `nhanesCodebook()` during load)
- Optional: Bash + `curl` (or WSL) for the local sync script

## Database setup

### 1. Install and start PostgreSQL 18

Ensure the service is running and listening on **5432** (or set `DB_PORT` to match).

### 2. Create role and database

```sql
CREATE ROLE your_user LOGIN PASSWORD 'your_password' SUPERUSER;
CREATE DATABASE "NHANES_2017-2018" OWNER your_user;
```

### 3. Set credentials

**R** — create `.Renviron` in the project root (gitignored):

```
DB_USER=your_user
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432
```

Notes:

- Database name is set in R (`dbname = "NHANES_2017-2018"`), not in `.Renviron`.
- Restart R or call `readRenviron(".Renviron")` after edits.

**Python** — create `.env` in the project root (gitignored):

```
DB_USER=your_user
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432
DB_NAME=NHANES_2017-2018
```

Never commit `.Renviron` or `.env`.

### 4. Install R packages

```r
install.packages(c("haven", "nhanesA", "stringr", "RPostgreSQL", "DBI"))
```

### 5. Install Python packages

```powershell
pip install pandas sqlalchemy psycopg2-binary python-dotenv plotly kaleido numpy
```

## Usage

Work from the **project root** so relative paths, `.Renviron`, and `.env` resolve correctly.

### Load survey tables + codebook

```r
source("data/ingest/write_tables_to_DB.R")
```

What the script does:

1. Reads `.Renviron` and connects to PostgreSQL.
2. Reads each local `.xpt` with `haven::read_xpt` (raw codes, not translated labels).
3. For each table, calls `nhanesA::nhanesCodebook(file)` (wrapped in `tryCatch`).
4. Collects per-variable codebook entries, skipping `SEQN`.
5. Writes one Postgres table per questionnaire (`DPQ_J`, `DEMO_J`, …) with `overwrite = TRUE`.
6. Flattens nested codebook objects into a single data frame and writes table **`codebook`**.

#### `codebook` table shape

| Column     | Content                                               |
| ---------- | ----------------------------------------------------- |
| `form`     | Questionnaire / table id (e.g. `DPQ_J`)               |
| `variable` | Column / question id (e.g. `DPQ010`)                  |
| `code`     | Stored value in the survey table (e.g. `0`, `1`, `7`) |
| `meaning`  | CDC value description (e.g. `Not at all`)             |

Entries without an answers table (e.g. skip-logic “BOX” items) are skipped. If `nhanesCodebook` fails for a file (package/HTML issue), that file’s codebook is skipped with a warning; other tables still load.

Example:

```sql
SELECT * FROM codebook WHERE form = 'DPQ_J' AND variable = 'DPQ010';
```

Join labels when displaying results (codes stay in the survey table):

```sql
SELECT d."SEQN", d."DPQ010", c.meaning
FROM "DPQ_J" d
LEFT JOIN codebook c
  ON c.form = 'DPQ_J'
 AND c.variable = 'DPQ010'
 AND c.code = d."DPQ010"::text
LIMIT 10;
```

### Query notes

- Quote mixed-case names: `"DPQ_J"`, `"SEQN"`.
- Filter on **codes**, not label text, unless you join `codebook`.
- Main analysis subset: `data/sql/subset_for_psych_and_diet_metrics.sql`  
  - Spine: `DEMO_J` ⋈ `DPQ_J` (adults, age ≥ 18)  
  - LEFT JOIN: diet behavior (`DBQ_J`), food security (`FSQ_J`), day-1/2 totals (`DR1TOT_J` / `DR2TOT_J`), body measures (`BMX_J`), smoking (`SMQ_J`)  
  - Survey weights are omitted on purpose (sample-only analysis; see Data notes)
- Smaller example: `data/sql/demo.sql`

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h localhost -U your_user -d "NHANES_2017-2018"
```

### Python plots

```powershell
python src/consume/data_plotter.py
```

What the script does:

1. Loads `.env` and connects via SQLAlchemy (`postgresql+psycopg2`).
2. Runs `subset_for_psych_and_diet_metrics.sql`.
3. Builds age groups and a 2-day mean total sugar (`DR1TSUGR` / `DR2TSUGR`, both required).
4. Plots BMI vs mean sugar in one Plotly subplot per age band (OLS line + Pearson `r`).
5. Writes `data/static/figures/bmi_sugar_intake.html` and `.pdf` (PDF needs `kaleido`).

### Human-readable reference (optional)

`data/raw/nhanes/2017-2018/_file_list.txt` remains a manual Ctrl+F reference (form / question / codes). The live lookup used by SQL is the Postgres **`codebook`** table built from `nhanesCodebook`.

## Data notes

- Public-use NHANES only; join key across files is `SEQN`.
- Some files have **multiple rows per `SEQN`**. A primary key on `SEQN` alone is not valid for every table.
- Adult PHQ-9 items are in public `DPQ_J` (age ≥ 18 in this pipeline). Youth PHQ (`DPQY_J_R`) is RDC-only and not used here.
- Analyses currently treat the extract as an **unweighted sample** (“among respondents with available data”), not as nationally representative US adults. Survey weights (`WTMEC2YR`, dietary weights, etc.) are intentionally left out of the analysis SQL until weighting is designed in.
- Do not commit `.Renviron`, `.env`, or raw clinical extracts.

## Status

- Download + local XPT cache: in place (sync helper local/gitignored)
- Human codebook text (`_file_list.txt`): in place
- PostgreSQL load of raw-coded survey tables: implemented (`data/ingest/write_tables_to_DB.R`)
- Postgres `codebook` lookup from `nhanesCodebook`: implemented (flattened `form` / `variable` / `code` / `meaning`)
- SQL exploration (`data/sql/`): psych + diet subset in place
- Python analysis (`src/consume/data_plotter.py`): Plotly BMI vs 2-day mean sugar by age
- PHQ-9 scoring / further psych metrics: not yet implemented
- Formal schema / primary keys: not finalized
