library(haven)
library(nhanesA)
library(stringr)

acq <- read_xpt("data/raw/nhanes/2017-2018/ACQ_J.xpt")   # local file, coded values

nhanesTableVars("Q", "ACQ_J")                            # column names + labels, Q is the question number, ACQ_J is the dataset name
nhanesCodebook("ACQ_J", "ACD011A")                       # what each code means, ACD011A is the variable name

acq_text <- nhanesTranslate("ACQ_J", colnames = c("ACD011A", "ACD011B", "ACD011C", "ACD040", "ACD110"),
                            data = acq)                  # apply codes to local data, acq is the dataset name

# Fetch .xpt file list
xpt_files <- list.files("data/raw/nhanes/2017-2018", pattern = "\\.xpt$", full.names = FALSE)

for (i in seq_along(xpt_files)) {
    xpt_files[i] <- str_split(xpt_files[i], pattern = "\\.")[[1]][1]
}