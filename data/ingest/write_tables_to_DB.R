# Load libraries
library(haven)
library(stringr)
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

# Initialize list for dataframes to be written to the database
dfs <- list()

# Fetch .xpt file list
xpt_files <- list.files(
    "data/raw/nhanes/2017-2018",
    pattern = "\\.xpt$",
    full.names = FALSE
)

# Iterate through each member of xpt_files
for (i in seq_along(xpt_files)) {
    # Extract the extensionless filename
    xpt_files[i] <- str_split(xpt_files[i], pattern = "\\.")[[1]][1]
    # Point to a specific .xpt file
    file <- xpt_files[i]
    # Read the local .xpt file
    df <- read_xpt(file.path("data/raw/nhanes/2017-2018", paste0(file, ".xpt")))
    # Save the dataframe to the list
    dfs[[i]] <- df
}

# Iterate through dataframes within the dfs list 
for (i in seq_along(dfs)) {
    # Upload dataframe with auto-recognized column types
    # Table names match original .xpts
    dbWriteTable(
        conn = con,
        name = xpt_files[i],
        value = dfs[[i]],
        row.names = FALSE,
        overwrite = TRUE
    )
}

# Disconnect from the database (or do it manually)
dbDisconnect(con)
