# Clinical data pipeline (NHANES)

Portfolio project demonstrating end-to-end clinical data analysis workflows: ingest public survey data, decode coded variables with official metadata, and load curated tables into a relational database.

## Overview

The pipeline works with the CDC [NHANES 2017–2018](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/default.aspx?BeginYear=2017) public release (file suffix `_J`): demographics, exams, labs, questionnaires, and dietary files. Tables join on `SEQN`.

| Stage | Role |
| --- | --- |
| Download | Pull public `.xpt` files into `data/raw/nhanes/2017-2018/` |
| Document | Column and value-code dictionary in `_file_list.txt` |
| Translate | Decode coded answers via `nhanesA` |
| Migrate | Load translated frames into PostgreSQL |

## Repository layout

```
data/
  sync_nhanes.sh              # Discover and download NHANES XPTs (local only)
  translate_columns.R         # Decode coded columns into translated_dfs
  migrate_dataframes.R        # DB connection + orchestration (local only)
  raw/nhanes/2017-2018/       # Local XPTs + _file_list.txt
  processed/                  # Intermediate outputs (gitignored)
src/                          # Reserved for Python consumers / ingest helpers
tests/
```

Raw XPT files and secrets are not committed. Scripts that hold environment-specific paths or credentials stay local via `.gitignore`.

## Requirements

- R ≥ 4.x with packages: `haven`, `nhanesA`, `stringr`, `RPostgreSQL` (or `RPostgres`)
- PostgreSQL (for the migrate step)
- Bash + `curl` + Python 3 (for `sync_nhanes.sh`; WSL works on Windows)
- Network access to `wwwn.cdc.gov`

## Setup

1. Clone the repository and open it as the working directory.
2. Create `.Renviron` in the project root (gitignored):

   ```
   DB_USER=
   DB_PASSWORD=
   DB_NAME=
   DB_HOST=
   ```

3. Install R packages:

   ```r
   install.packages(c("haven", "nhanesA", "stringr", "RPostgreSQL"))
   ```

4. Download the NHANES files (if not already present):

   ```bash
   bash data/sync_nhanes.sh
   ```

## Usage

From the project root:

```r
source("data/migrate_dataframes.R")
```

That script loads credentials from `.Renviron` and sources the translation step. Translation alone:

```r
source("data/translate_columns.R")
# translated_dfs[[i]] — one data frame per XPT file
```

Metadata for scripting (labels and value codes) lives in:

```
data/raw/nhanes/2017-2018/_file_list.txt
```

Parse it as pipe-delimited `ABBR` / `FILE` / `VAR` / `CODE` records (see the header of that file).

## Data notes

- Source: CDC / NCHS NHANES; public use files only.
- Join key across files: `SEQN`.
- Survey weights in `DEMO_J` are required for nationally representative estimates.
- Do not commit `.Renviron`, `.env`, or raw clinical extracts.

## Status

Active development: download and codebook documentation are in place; column translation is implemented; PostgreSQL load and schema finalization are in progress.
