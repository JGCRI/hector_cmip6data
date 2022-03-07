# ------------------------------------------------------------------------------
# Program Name: B2.processing_tas_land.R
# Authors: Leeya Pressburger
# Date Last Modified: February 2022
# Program Purpose: Processing CMIP6 tas data and calculating Tgav (over land)
# TODO:
# ------------------------------------------------------------------------------

# Import packages
library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)

# Set directory, read in files
BASE_DIR <- here::here()
path = paste0(BASE_DIR, "/tas_land")

files <- list.files(path = path, pattern = "*.csv", full.names = TRUE)

# Read in data, forcing column types
data <- lapply(files, read_csv, col_types = "dccccccdd") %>%
  bind_rows(.id = "File")

# Add name and row number identifier
data$name <- paste0(data$model, "_", data$experiment, "_", data$ensemble)
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
# What models have Tgav values
models <- historical$model

# Filter and calculate
Tgav_land <- tas %>%
  filter(model %in% models, !experiment == "esm-hist") %>%
  left_join(historical, by = "model") %>%
  mutate(Tgav = value - avg)

Tgav_out <- Tgav_land %>% select(c(rownum, Tgav))

# Save outputs
output <- left_join(tas, Tgav_out, by = "rownum")
output$type = "land"

# Data visualization
# Graph tas_global vs tas_land - only for models with Tgav values
Tgav_land$type <- "land"

# Combine global and land values
# Access only needed columns
Tgav_l_plot <- Tgav_land %>%
  select(c(year, value, model, experiment, ensemble, type))

# Using Tgav from "processing_tas.R"
Tgav <- read.csv("./outputs/cmip6_annual_tas_global.csv")
Tgav_plot <- Tgav %>%
  select(year, value, model, experiment, ensemble, type)

plot_data <- bind_rows(Tgav_l_plot, Tgav_plot)

Tgav_models_compare <- plot_data %>%
  # This model has an abnormally low tas_land value
  filter(model != "MPI-ESM1-2-LR") %>%
  ggplot(aes(year, value, color = type, 
             group = paste0(model, experiment, ensemble, type))) +
  geom_line() +
  facet_wrap(~experiment, scales = "free") +
  labs(x = "Year",
       y = "tas",
       title = "CMIP6 runs - tas over time (models with Tgav values)") +
  theme_minimal()

# All models
tas$type = "land"
tas_l_plot <- tas %>%
  select(c(year, value, model, experiment, ensemble, type))

# Using Tgav from "processing_tas.R" (same as above)
tas_plot <- Tgav %>%
  select(year, value, model, experiment, ensemble, type)

plot_all_data <- bind_rows(tas_l_plot, tas_plot)

# Some models have very low tas_land values
low_models <- tas %>% 
  filter(value < 200)
low_models <- unique(low_models$model)

all_models_compare <- plot_all_data %>%
  # These model have abnormally low tas_land values
  filter(!model %in% low_models) %>%
  ggplot(aes(year, value, color = type, 
             group = paste0(model, experiment, ensemble, type))) +
  geom_line() +
  facet_wrap(~experiment, scales = "free") +
  labs(x = "Year",
       y = "tas",
       title = "CMIP6 runs - tas over time") +
  theme_minimal()

# Plot just tas_land models
tas_land_plot <- tas %>%
  filter(!model %in% low_models) %>%
  ggplot(aes(year, value, color = model, 
             group = paste0(model, experiment, ensemble))) +
  geom_line() +
  facet_wrap(~experiment, scales = "free") +
  labs(x = "Year",
       y = "tas",
       title = "CMIP6 runs - tas over time") +
  theme_minimal()

# Clean up output data, save csv
output <- output %>%
  select(c(model, experiment, ensemble, variable, units, year, value, Tgav, type)) %>%
  filter(!model %in% low_models)

write.csv(output, "./outputs/cmip6_annual_tas_over_land.csv", row.names = FALSE)
