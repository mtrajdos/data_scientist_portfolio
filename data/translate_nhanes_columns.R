# Load libraries
library(haven)
library(nhanesA)
library(stringr)

# Initialize list for translated dataframes
translated_dfs <- list()

# Fetch .xpt file list
xpt_files <- list.files(
    "data/raw/nhanes/2017-2018",
    pattern = "\\.xpt$",
    full.names = FALSE
)

# Iterate through each member of xpt_files
for (i in seq_along(xpt_files)) {
    # extract the extensionless filename
    xpt_files[i] <- str_split(xpt_files[i], pattern = "\\.")[[1]][1]
    # point to a specific .xpt file
    file <- xpt_files[i]
    # call nhanes package for column translations
    df <- nhanes(file)
    # Translate the coded-answers in .xpt by matching column names with nhanesTranslate
    # and save to the list of translated_dfs
    translated_dfs[[i]] <- nhanesTranslate(file, names(df), data = df)
}