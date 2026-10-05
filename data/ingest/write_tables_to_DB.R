# Load libraries
library(haven)
library(stringr)
library(RPostgreSQL)
library(DBI)
library(nhanesA)

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
data_dfs <- list()
lookup_dfs <- list()

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
    data_dfs[[i]] <- df
    # Create an .xpt-file-specific codebook dataframe. If the codebook is not found, return NULL
    cb_df <- tryCatch(nhanesCodebook(file), error = function(e) NULL)
    # Proceed with the next table if the codebook is not found
    if (is.null(cb_df) || length(cb_df) == 0) {
        warning(paste0("No codebook found for ", file, ". Skipping..."))
        next
    }
    # Get all columns except for the SEQN
    vars <- setdiff(names(cb_df), "SEQN")

    # If the datafarme has a valid codebook
    if (length(cb_df) != 0) {
        # Iterate through column names
        for (j in seq_along(vars)) {
            # Save the codebook to the lookup_dfs: +1 to shift the index and a
            lookup_dfs[[length(lookup_dfs) + 1]] <- cb_df[[vars[j]]]
        }
    }
}

# Iterate through dataframes within the dfs list
for (i in seq_along(data_dfs)) {
    # Upload dataframe with auto-recognized column types
    # Table names match original .xpts
    dbWriteTable(
        conn = con,
        name = xpt_files[i],
        value = data_dfs[[i]],
        row.names = FALSE,
        overwrite = TRUE
    )
}

# Build one tidy codebook data.frame, then upload it
# dbWriteTable cannot store lookup_dfs list as-is — Postgres needs a flat table.
if (length(lookup_dfs) > 0) {
    # Empty list; each code row we extract will be stored here as a small data.frame
    rows <- list()

    # Walk every variable codebook collected earlier
    for (item in lookup_dfs) {
        # Human-readable name of this column, e.g. "ACD011A"
        var <- item[["Variable Name:"]]

        # The answers table is stored under that same name inside the nested list
        # if the variable name does not have any data, proceed with the next item
        if (length(var) != 1 || is.na(var) || !var %in% names(item)) {
            next
        }
        # The answers table is stored under that same name inside the nested list
        code_tbl <- item[[var]]
        # if the answers table is not a data.frame, proceed with the next item
        if (!is.data.frame(code_tbl)) {
            next
        }
        # One small data.frame with one row per answer code for this variable
        rows[[length(rows) + 1]] <- data.frame(
            variable = var,
            code = code_tbl[["Code or Value"]],
            meaning = code_tbl[["Value Description"]],
            stringsAsFactors = FALSE
        )
    }

    # Stack all those small tables into one big codebook
    codebook <- do.call(rbind, rows)

    # Write the flat codebook to Postgres
    dbWriteTable(
        conn = con,
        name = "codebook",
        value = codebook,
        row.names = FALSE,
        overwrite = TRUE
    )
}

# Disconnect from the database (or do it manually)
# dbDisconnect(con)
