# ------------------------------------------------------------------------------
# Program Name: B5b.process_historical_regional_tos.R
# Authors: Kalyn Dorheim
# Date Last Modified: March 2022
# Program Purpose: Post-processing of global & regional tos data, converts from absolute
# temperature to temperature anomaly and general clean up.
# Outputs: A single long data frame stored as csv file in the output directory that is to be used
# in C5b.ocean_component-tos_data.Rmd which prepares the data for the Hector ocean component.
# TODO:

# Load library
library(assertthat)
library(dplyr)
library(magrittr)

# 1. Import data ------------------------------------------------------------------------------------------
# Import the data files, keep the data for only a limited number of years. Make sure that the
# data is the annual, some data that was processed was only monthly.
YEARS <- 1850:1860

here::here("tos", "global") %>%
  list.files(pattern = "csv", full.names = TRUE) %>%
  lapply(function(f){
    data <- read.csv(f, stringsAsFactors = FALSE)
    suppressMessages({
      data %>%
        filter(experiment == "historical") %>% 
        group_by(variable, experiment, units, ensemble, model, area, year) %>%
        summarise(value = mean(value)) %>%
        ungroup() %>%
        filter(year %in% YEARS) ->
        data
    })
    assert_that(isFALSE(any(is.na(data))), msg = "NA in the data")
    assert_that(all(diff(data$year) == 1), msg = "year diff is not equal to 1")
    
    return(data)
  }) %>%
  do.call(what = "rbind") %>%
  distinct() ->
  global_data

here::here("tos", "HL") %>%
  list.files(pattern = "csv", full.names = TRUE) %>%
  lapply(function(f){
    data <- read.csv(f, stringsAsFactors = FALSE)
    suppressMessages({
      data %>%
        filter(experiment == "historical") %>% 
        group_by(variable, experiment, units, ensemble, model, area, year) %>%
        summarise(value = mean(value)) %>%
        ungroup() %>%
        filter(year %in% YEARS) ->
        data
    })
    assert_that(isFALSE(any(is.na(data))), msg = "NA in the data")
    assert_that(all(diff(data$year) == 1), msg = "year diff is not equal to 1")
    
    return(data)
  }) %>%
  do.call(what = "rbind") %>%
  distinct() ->
  HL_data

here::here("tos", "LL") %>%
  list.files(pattern = "csv", full.names = TRUE) %>%
  lapply(function(f){
    data <- read.csv(f, stringsAsFactors = FALSE)
    suppressMessages({
      data %>%
        filter(experiment == "historical") %>% 
        group_by(variable, experiment, units, ensemble, model, area, year) %>%
        summarise(value = mean(value)) %>%
        ungroup() %>%
        filter(year %in% YEARS) ->
        data
    })
    assert_that(isFALSE(any(is.na(data))), msg = "NA in the data")
    assert_that(all(diff(data$year) == 1), msg = "year diff is not equal to 1")
    
    return(data)
  }) %>%
  do.call(what = "rbind") %>%
  distinct() ->
  LL_data


# 2. Data coverage ------------------------------------------------------------------------------------------
# Make sure that there is data for all of the areas HL, LL, and global. If not the discard the data.
global_data %>%
  select(variable, experiment, units, ensemble, model) %>%
  mutate(global = 1) ->
  global_meta_info

LL_data %>%
  select(variable, experiment, ensemble, model) %>%
  mutate(LL = 1) %>%  
  distinct -> 
  LL_meta_info

HL_data %>%
  select(variable, experiment, ensemble, model) %>%
  mutate(HL = 1) %>% 
  distinct -> 
  HL_meta_info

global_meta_info %>%
  left_join(LL_meta_info, by = c("variable", "experiment", "ensemble", "model")) %>%
  left_join(HL_meta_info, by = c("variable", "experiment", "ensemble", "model")) %>%
  na.omit %>%
  select(experiment, ensemble, model) %>%
  distinct ->
  data_to_keep

bind_rows(global_data, LL_data, HL_data) %>%
  inner_join(data_to_keep, by = c("experiment", "ensemble", "model")) %>%
  group_by(variable, experiment, units, ensemble, model, area, year) %>%
  summarise(value = mean(value)) %>%
  ungroup() %>%
  distinct() %>%
  na.omit() ->
  data

# 3.  Check to make sure that the HL & LL aggregate to global ------------------------------------------------------------------------------------------
# If the data doesn't aggregate to the global value, the exclude the data.

# Fraction of HL and LL  from Hector's def.
HL_frac <- 0.15
LL_frac <- 1 - HL_frac

# Get the weighed sum of the tos and compare it to the global value. 
# Discard the values that are different from one another. 
data %>%
  tidyr::spread(area, value) %>%
  mutate(total = HL * HL_frac + LL * LL_frac) %>%
  mutate(diff = abs(global - total)) %>%
  filter(diff < 0.1) %>%
  select(variable, experiment, units, ensemble, model, year, global, HL, LL) %>%
  tidyr::gather(key = "area", value = "value", global, HL, LL) ->
  data


# 4. Check for abnormal results ------------------------------------------------------------------------------------------

data %>%
  dplyr::filter(year == 1850) %>%
  dplyr::filter( (area == "global" & value <= 16) | (area == "HL" & value <= 1e-3) | (area == "LL" & value <= 1e-3))  %>%
  dplyr::select(model, ensemble) %>%
  distinct() ->
  discard_these

data %>%
  dplyr::anti_join(discard_these, by = c("ensemble", "model")) ->
  data

# Get some summary information to figure out the range to judge if there is some issue with
# results from some model.
data %>%
  group_by(area) %>%
  summarise(min = min(value),
            mean = mean(value),
            max = max(value)) %>%
  mutate(range = max - min) ->
  summary_stats


if (any(summary_stats$range > 10)){
  stop("Potential problem with data, large range found take a look at the summary_stats")
}

# 5. Save data ------------------------------------------------------------------------------------------
ofile <- file.path(here::here("tos"), 'historical_HL_LL_global_tos.csv')
write.csv(data, file = ofile, row.names = FALSE)



