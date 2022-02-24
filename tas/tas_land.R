library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)

BASE_DIR <- here::here()
path = paste0(BASE_DIR, "/tas_land")

files <- list.files(path = path, pattern = "*.csv", full.names = TRUE)

# Read in data, forcing column types
data <- lapply(files, read_csv, col_types = "dccccccdd") %>%
  bind_rows(.id = "File")

# Add name and row number identifier
data$name <- paste0(data$model, "_", data$ensemble, "_", data$experiment)
data$rownum <- seq_len(nrow(data))

# Correct non-conventional years in CO2 forcing experiments
# Scale to start at 1850
years <- data %>%
  select("rownum", "year", "File") %>%
  filter(year < 1850 | year > 2500) %>%
  group_by(File) %>%
  mutate(start_year = year[1],
         scale = year - start_year,
         new_year = 1850 + scale) %>%
  select("rownum", "new_year")

# Combine with original dataframe
tas <- left_join(data, years, by = "rownum")

# Problem - need to make one year column with "year" and "new_year"
# If new_year has an NA, replace it with year, otherwise leave as is
replace_year <- ifelse(is.na(tas$new_year), 
                       tas$year, 
                       tas$new_year)

tas$year <- replace_year

# Get rid of unnecessary columns
tas <- tas %>% select(c(-new_year, -File.y, -X1))

# Get historical average
hist <- tas %>%
  filter(experiment == "esm-hist") %>%
  group_by(model) %>%
  mutate(hist_av = mean(value))

# Isolate models and their historical averages
historical <- as.data.frame(unique(hist$model))
historical$avg <- unique(hist$hist_av)
colnames(historical) <- c("model", "avg")

# Calculate Tgav
models <- historical$model
Tgav <- tas %>%
  filter(model %in% models, !experiment == "esm-hist") %>%
  left_join(historical, by = "model") %>%
  mutate(Tgav = value - avg)
