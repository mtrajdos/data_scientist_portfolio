# Clinical data pipeline (NHANES)

Portfolio project for end-to-end clinical survey workflows: download public NHANES files, decode coded variables with CDC metadata, load curated tables into PostgreSQL, and explore them with SQL.

## Tech stack

| Layer | Tools |
| --- | --- |
| Data source | CDC / NCHS [NHANES 2017–2018](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/default.aspx?BeginYear=2017) (file suffix `_J`) |
| Ingest / transform | **R** (≥ 4.x): `haven`, `nhanesA`, `stringr` |
| Database driver (R) | `RPostgreSQL` + `DBI` |
| Database | **PostgreSQL 18** (developed against 18.6) |
| Exploration | SQL files under `data/sql/`; `psql` or a Cursor DB client (e.g. DBCode) |
| Planned consumers | Python (`src/`) for later analysis / ingest helpers |
| OS notes | Windows-friendly; Bash download helper is optional/local |

## Pipeline overview

| Stage | What runs | Output |
| --- | --- | --- |
| Download | Local `data/sync_nhanes.sh` (gitignored) | `.xpt` files in `data/raw/nhanes/2017-2018/` |
| Document | `data/raw/nhanes/2017-2018/_file_list.txt` | Table → column → answer-code reference |
| Translate | `data/translate_nhanes_columns.R` | `translated_dfs` + `xpt_files` in the R session |
| Load | `data/write_tables_to_DB.R` | One Postgres table per XPT (names match stems, e.g. `DPQ_J`) |
| Query | `data/sql/*.sql` | Ad-hoc exploration against the loaded DB |

Tables join on `SEQN` (respondent ID). After translation, coded answers are stored as **label text** (e.g. `'Nearly every day'`), not raw numeric codes.

## Repository layout

```
data/
  translate_nhanes_columns.R   # Decode coded columns via nhanesA
  write_tables_to_DB.R         # Connect + write all tables to PostgreSQL
  sql/                         # Exploratory SQL (e.g. demo.sql)
  queried/                     # Placeholder for query exports
  raw/nhanes/2017-2018/        # Local XPTs + _file_list.txt
  processed/                   # Intermediate outputs (gitignored)
src/                           # Python package stub (future consumers)
tests/
.Renviron                      # DB credentials (gitignored; create locally)
```

Raw XPTs and secrets are not committed. Environment-specific helpers such as `data/sync_nhanes.sh` stay local via `.gitignore`.

## Requirements

- **R** ≥ 4.x  
  Packages: `haven`, `nhanesA`, `stringr`, `RPostgreSQL`, `DBI`
- **PostgreSQL 18** (server running and accepting TCP connections)  
  Developed/tested with **PostgreSQL 18.6**. Use 18.x to match this project; create the target database before loading.
- Network access to `wwwn.cdc.gov` (for download / `nhanesA` codebook calls)
- Optional: Bash + `curl` (or WSL) if using the local sync script; Python 3 for future `src/` work

## Database setup

### 1. Install and start PostgreSQL 18

Install PostgreSQL 18 and ensure the service is running (default port **5432**).

### 2. Create role and database

From `psql` as a superuser (often `postgres`), create a login role and the project database. Names must match what you put in `.Renviron` / the R script:

```sql
CREATE ROLE your_user LOGIN PASSWORD 'your_password' SUPERUSER;
CREATE DATABASE "NHANES_2017-2018" OWNER your_user;
```

The load script currently connects to database name `NHANES_2017-2018` (quoted because of the hyphen).

### 3. Set credentials in `.Renviron`

Create `.Renviron` in the **project root** (gitignored). Required keys used by `write_tables_to_DB.R`:

```
DB_USER=your_user
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432
```

Notes:

- Do **not** put the port in `DB_HOST` (use `localhost`, not `localhost:5432`).
- `DB_PORT` must be the port Postgres actually listens on (usually `5432`).
- The database name is set in R (`dbname = "NHANES_2017-2018"`), not via `.Renviron`.
- After editing `.Renviron`, restart the R session or call `readRenviron(".Renviron")` before connecting.
- Never commit `.Renviron`.

### 4. Install R packages

```r
install.packages(c("haven", "nhanesA", "stringr", "RPostgreSQL", "DBI"))
```

## Usage

Work from the **project root** so relative paths and `.Renviron` resolve correctly.

### Load all translated tables into PostgreSQL

```r
source("data/write_tables_to_DB.R")
```

This script:

1. Reads `.Renviron`
2. Connects with `RPostgreSQL` / `DBI`
3. Sources `data/translate_nhanes_columns.R`
4. Writes each frame with `dbWriteTable(..., overwrite = TRUE)`

Translation alone (no DB write):

```r
source("data/translate_nhanes_columns.R")
# translated_dfs[[i]] — one data frame per XPT
# xpt_files[i]        — matching table name (extension stripped)
```

### Query the database

Table and column names are mixed-case; quote them in SQL:

```sql
SELECT * FROM "DPQ_J" WHERE "DPQ010" = 'Nearly every day' LIMIT 5;
```

Example exploratory query: `data/sql/demo.sql`.

Use `psql`:

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h localhost -U your_user -d "NHANES_2017-2018"
```

Or a SQL client inside Cursor (e.g. DBCode) pointed at the same host/port/database.

### Codebook reference

Human-readable column/answer guide:

```
data/raw/nhanes/2017-2018/_file_list.txt
```

Layout (`-----` separates forms, `---` separates questions, ` | ` separates fields):

```text
-----

INQ_J | Income

INQ020 | Income from wages/salaries
1 | Yes
2 | No
7 | Refused

---

INQ012 | Income from self employment
...
```

## Data notes

- Public-use NHANES only; join key across files is `SEQN`.
- Some files have **multiple rows per `SEQN`** (repeated measures). A primary key on `SEQN` alone is not valid for every table; uniqueness is enforced in analysis when needed.
- Survey weights in `DEMO_J` are required for nationally representative estimates.
- Do not commit `.Renviron`, `.env`, or raw clinical extracts.

## Status

- Download + local XPT cache: in place (sync helper local/gitignored)
- Codebook reference (`_file_list.txt`): in place
- Column translation (`translate_nhanes_columns.R`): implemented
- PostgreSQL load (`write_tables_to_DB.R`): implemented
- SQL exploration (`data/sql/`): started
- Python analysis consumers (`src/`): stub only
- Formal schema / primary keys: not finalized (load uses inferred types; no PK step)
