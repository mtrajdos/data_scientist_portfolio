library(RPostgreSQL)
library(DBI)

# Connect to PostgreSQL driver
drv <- dbDriver("PostgreSQL")

# Load R environment (with DB credentials)
readRenviron(".Renviron")

# Connect to PostgreSQL
# Credentials are pulled from .Renviron
con <- dbConnect(
    drv,
    dbname = "NHANES_2017-2018",
    host = Sys.getenv("DB_HOST"),
    port = Sys.getenv("DB_PORT"),
    user = Sys.getenv("DB_USER"),
    password = Sys.getenv("DB_PASSWORD")
)

# Populate translated dataframes - provides translated_dfs list
source("data/translate_nhanes_columns.R")

# Iterate through dataframes within the translated_dfs list
for (i in seq_along(translated_dfs)) {
    # Upload dataframe with auto-recognized column types
    # and pre-defined Primary Key as SEQN
    # Table names match original .xpts
    dbWriteTable(
        conn = con,
        name = xpt_files[i],
        value = translated_dfs[[i]],
        row.names = FALSE,
        overwrite = TRUE
    )
}

# Disconnect from the database (or do it manually)
# dbDisconnect(con)
