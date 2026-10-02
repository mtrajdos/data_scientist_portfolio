library(RPostgreSQL)

# Connect to PostgreSQL driver
drv <- dbDriver("PostgreSQL")

# Load R environment (with DB credentials)
readRenviron(".Renviron")

# Populate translated dataframes
source('data/translate_column_codes.R')