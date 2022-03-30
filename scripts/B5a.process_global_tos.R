# ------------------------------------------------------------------------------
# Program Name: B5a.processing_tos.R
# Authors: Kalyn Dorheim
# Date Last Modified: March 2022
# Program Purpose: Post processing of global tos data, converts from absolute 
# temperature to temperature anomaly and general clean up.
# Outputs: A single long data frame stored as csv file in the output directory 
# that is ready to be compared with Hector results. 
# TODO:
# 0. Script Set Up -------------------------------------------------------------
# Load the required libraries
library(assertthat)
library(dplyr)
library(ggplot2)
library(magrittr)


OUTPUT_DIR <- here::here("outputs")

# 1. Import data ------------------------------------------------------------------------------------------
# Import the data files, keep the data for only a limited number of years. Make sure that the
# data is the annual, some data that was processed was only monthly.

here::here("tos", "global") %>%
  list.files(pattern = "csv", full.names = TRUE) %>%
  lapply(function(f){
    data <- read.csv(f, stringsAsFactors = FALSE)
    suppressMessages({
      data %>%
        group_by(variable, experiment, units, ensemble, model, area, year) %>%
        summarise(value = mean(value)) %>%
        ungroup() ->
        data
    })
    assert_that(isFALSE(any(is.na(data))), msg = "NA in the data")
    assert_that(all(diff(data$year) == 1), msg = "year diff is not equal to 1")
    
    return(data)
  }) %>%
  do.call(what = "rbind") %>%
  distinct() ->
  global_data

# 1. Data coverage ------------------------------------------------------------------------------------------
# Make sure that there are  historical results for every future result. 
# 
# Figure out which models & ensembles have historical data. 
global_data %>%
  filter(experiment == "historical") %>% 
  select(ensemble, model) %>% 
  distinct() %>% 
  mutate(keep = 1) -> 
  hist_model_ensemble

# Subset the tos data so that it only contains results for the models & ensemble
# realizations that have existing historical data. 
global_data %>% 
  left_join(hist_model_ensemble, by = c("ensemble", "model")) %>% 
  filter(keep == 1) %>%
  select(-keep) ->
  tos_data


# 2. Temperature anomaly  ------------------------------------------------------------------------------------------
# Calculate the average temperature for the reference period (1850 to 1860) for each model / ensemble to be used 
# to convert from absolute temperature to temperature anomoly. 
tos_data %>%  
  filter(year %in% 1850:1860) %>% 
  group_by(model, ensemble) %>% 
  summarise(ref_value = mean(value)) %>% 
  ungroup() -> 
  tos_ref_df

tos_data %>% 
  left_join(tos_ref_df, by = c("ensemble", "model")) %>% 
  mutate(value = value - ref_value) %>% 
  select(variable, experiment, units, ensemble, model, year, value) -> 
  tos_data
  
# 3. Clean Up Data ------------------------------------------------------------------------------------------
# Looking at the data to figure outliers 

tos_data %>% 
  ggplot(aes(year, value, color = model, group = interaction(model, ensemble, experiment))) + 
  geom_line()

tos_data %>% 
  filter(model == "FGOALS-g3") %>% 
  ggplot(aes(year, value, color = experiment)) + 
  geom_line()

remove_models <- c("FGOALS-g3", "CESM2-FV2")

tos_data <- filter(tos_data, !model %in%  remove_models)

# 5. Save results ------------------------------------------------------------------------------------------
tos_data %>% 
  select(model, experiment, ensemble, variable, year, value, units) %>% 
  write.csv(file = file.path(OUTPUT_DIR, "cmip6_annual_tos_global.csv"), row.names = FALSE)
