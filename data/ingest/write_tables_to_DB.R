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
    # Create an .xpt-file-specific codebook. If the codebook is not found, return NULL
    cb_df <- tryCatch(nhanesCodebook(file), error = function(e) NULL)
    # Proceed with the next table if the codebook is not found
    if (is.null(cb_df) || length(cb_df) == 0) {
        warning(paste0("No codebook found for ", file, ". Skipping..."))
        next
    }

    # If the dataframe has a valid codebook
    if (length(cb_df) != 0) {
        # Get all columns except for SEQN (same ID everywhere; not useful in the lookup)
        vars <- setdiff(names(cb_df), "SEQN")

        # Iterate through those variable names
        for (j in seq_along(vars)) {
            # Append one list entry per variable.
            # length(lookup_dfs) + 1 grows the list across forms (do not reuse j,
            # or each new questionnaire would overwrite slots 1, 2, 3, ...).
            # Structure of each lookup_dfs[[k]]:
            #   $form  - questionnaire id, e.g. "ACQ_J"
            #   $entry - nested nhanesCodebook list for one variable
            #            (Variable Name, SAS Label, ..., and optional answers tibble)
            lookup_dfs[[length(lookup_dfs) + 1]] <- list(
                form = file,
                entry = cb_df[[vars[j]]]
            )
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

# Build one tidy codebook data.frame, then upload it.
# dbWriteTable cannot store lookup_dfs as-is — Postgres needs a flat table.
# Target columns: form | variable | code | meaning
if (length(lookup_dfs) > 0) {
    # Empty list; each extracted answers block becomes a small data.frame here
    rows <- list()

    # Walk every collected form+entry pair (lookup_dfs[[1]], [[2]], ...)
    for (item in lookup_dfs) {
        # item is list(form = "...", entry = <nested codebook list>)
        # e.g. item$form == "ACQ_J"
        form <- item$form
        # entry is the original nhanesCodebook object for one variable
        # e.g. names(entry) include "Variable Name:", "SAS Label:", "ACD011A", ...
        entry <- item$entry

        # Read the question id written inside the nested list, e.g. "ACD011A"
        # Equivalent manual example:
        #   lookup_dfs[[2]]$entry[["Variable Name:"]]  -> "ACD011A"
        var <- entry[["Variable Name:"]]

        # Skip entries with no usable Variable Name, or where that name is not
        # a field on entry (skip-logic BOX items often have no answers tibble)
        if (length(var) != 1 || is.na(var) || !var %in% names(entry)) {
            next
        }

        # Pull the answers tibble by that name (not another loop — named lookup).
        # Equivalent manual example if entry is for ACD011A:
        #   code_tbl <- entry[["ACD011A"]]
        #   # same as lookup_dfs[[i]]$entry[["ACD011A"]]
        # [[ ]] returns the tibble itself; [ ] would wrap it in a length-1 list
        code_tbl <- entry[[var]]

        # If there is no answers table, skip (metadata-only / BOX entries)
        if (!is.data.frame(code_tbl)) {
            next
        }

        # One small data.frame with one row per answer code for this variable.
        # code_tbl is already a flat tibble; [[ ]] extracts columns as vectors
        # (needed for data.frame(...); [ ] would leave a one-column data.frame)
        rows[[length(rows) + 1]] <- data.frame(
            form = form,
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
