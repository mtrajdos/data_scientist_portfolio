# Clinical data pipeline (NHANES)

Portfolio project for end-to-end clinical survey workflows: download public NHANES files, load raw coded tables into PostgreSQL, build a code→label lookup table from CDC codebooks, and explore with SQL.

## Tech stack

| Layer               | Tools                                                                                                                           |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Data source         | CDC / NCHS [NHANES 2017–2018](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/default.aspx?BeginYear=2017) (file suffix `_J`) |
| Ingest              | **R** (≥ 4.x): `haven` (local `.xpt`), `nhanesA` (`nhanesCodebook`), `stringr`                                                  |
| Database driver (R) | `RPostgreSQL` + `DBI`                                                                                                           |
| Database            | **PostgreSQL 18** (developed against 18.6)                                                                                      |
| Exploration         | SQL under `data/sql/`; `psql` or a Cursor DB client (e.g. DBCode)                                                               |
| Planned consumers   | Python (`src/`) for later analysis / ingest helpers                                                                             |
| OS notes            | Windows-friendly; Bash download helper is optional/local                                                                        |

## Pipeline overview

| Stage    | What runs                                  | Output                                                     |
| -------- | ------------------------------------------ | ---------------------------------------------------------- |
| Download | Local sync helper (gitignored)             | `.xpt` files in `data/raw/nhanes/2017-2018/`               |
| Document | `data/raw/nhanes/2017-2018/_file_list.txt` | Human-readable form → question → code reference            |
| Load     | `data/ingest/write_tables_to_DB.R`         | One Postgres table per XPT **with raw numeric/text codes** |
| Codebook | Same script (`nhanesCodebook` → flatten)   | Postgres table `codebook` (`form`, `variable`, `code`, `meaning`)  |
| Query    | `data/sql/*.sql`                           | Ad-hoc exploration / joins to labels                       |

Tables join on `SEQN` (respondent ID). Survey tables keep **codes** (e.g. `0`, `1`, `3`). Human-readable labels live in the separate `codebook` table and are joined when needed.

## Repository layout

```
data/
  ingest/
    write_tables_to_DB.R       # Load XPTs + build/write codebook
  sql/                         # Exploratory SQL (e.g. demo.sql)
  queried/                     # Placeholder for query exports
  raw/nhanes/2017-2018/        # Local XPTs + _file_list.txt
  processed/                   # Intermediate outputs (gitignored)
src/                           # Python package stub (future consumers)
tests/
.Renviron                      # DB credentials (gitignored; create locally)
```

Raw XPTs and secrets are not committed. Environment-specific helpers such as the NHANES sync script stay local via `.gitignore`.

## Requirements

- **R** ≥ 4.x  
  Packages: `haven`, `nhanesA`, `stringr`, `RPostgreSQL`, `DBI`
- **PostgreSQL 18** (server running; default port **5432**)  
  Developed/tested with **PostgreSQL 18.6**
- Network access to `wwwn.cdc.gov` (required for `nhanesCodebook()` during load)
- Optional: Bash + `curl` (or WSL) for the local sync script; Python 3 for future `src/` work

## Database setup

### 1. Install and start PostgreSQL 18

Ensure the service is running and listening on **5432** (or set `DB_PORT` to match).

### 2. Create role and database

```sql
CREATE ROLE your_user LOGIN PASSWORD 'your_password' SUPERUSER;
CREATE DATABASE "NHANES_2017-2018" OWNER your_user;
```

### 3. Set credentials in `.Renviron`

Create `.Renviron` in the **project root** (gitignored):

```
DB_USER=your_user
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432
```

Notes:

- Database name is set in R (`dbname = "NHANES_2017-2018"`), not in `.Renviron`.
- Restart R or call `readRenviron(".Renviron")` after edits.
- Never commit `.Renviron`.

### 4. Install R packages

```r
install.packages(c("haven", "nhanesA", "stringr", "RPostgreSQL", "DBI"))
```

## Usage

Work from the **project root** so relative paths and `.Renviron` resolve correctly.

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
- Example ad-hoc SQL: `data/sql/demo.sql` (update filters to codes if it still uses old translated strings).

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h localhost -U your_user -d "NHANES_2017-2018"
```

### Human-readable reference (optional)

`data/raw/nhanes/2017-2018/_file_list.txt` remains a manual Ctrl+F reference (form / question / codes). The live lookup used by SQL is the Postgres **`codebook`** table built from `nhanesCodebook`.

## Data notes

- Public-use NHANES only; join key across files is `SEQN`.
- Some files have **multiple rows per `SEQN`**. A primary key on `SEQN` alone is not valid for every table.
- Survey weights in `DEMO_J` are required for nationally representative estimates.
- Do not commit `.Renviron`, `.env`, or raw clinical extracts.

## Status

- Download + local XPT cache: in place (sync helper local/gitignored)
- Human codebook text (`_file_list.txt`): in place
- PostgreSQL load of raw-coded survey tables: implemented (`data/ingest/write_tables_to_DB.R`)
- Postgres `codebook` lookup from `nhanesCodebook`: implemented (flattened `form` / `variable` / `code` / `meaning`)
- SQL exploration (`data/sql/`): started
- Python analysis consumers (`src/`): stub only
- Formal schema / primary keys: not finalized
