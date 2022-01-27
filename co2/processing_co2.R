library(readr)
library(dplyr)
library(ggplot2)
library(ncdf4)
library(here)

BASE_DIR <- here::here()

mypath <-  "C:/Users/pres520/PycharmProjects/pangeo/test"

files <- list.files(path = mypath, pattern = "*.csv", full.names = TRUE)

# Read in data, forcing column types
data <- lapply(files, read_csv, col_types = "dccccccdd") %>%
  bind_rows(.id = "File")

# Add name identifier
data$name <- paste0(data$model, "_", data$ensemble, "_", data$experiment)

# Non-conventional year numbering
weird_range <- data %>% filter(year < 1850 | year > 2500)
weird_range <- weird_range %>% mutate(ncdf = paste0(model, "_", ensemble, "_", experiment))
weird_models <- unique(weird_range$name)
weird_range$year <- weird_range$year + 1849

# Normal years (1850-2500)
normal_range <- data %>% filter(year > 1849 & year < 2500)
normal_range <- normal_range %>% bind_rows(normal_range, weird_range)

plot <- normal_range %>% 
  ggplot(aes(year, value, color = paste(model, experiment), group = paste(model, experiment, ensemble))) +
  geom_line() +
  facet_wrap(~experiment, scales = "free_x") +
  labs(x = "Year",
       y = "mol mol-1",
       title = "Atmospheric CO2 over time") +
  theme_minimal()

no_facet <- normal_range %>%
  ggplot(aes(year, value, color = paste(model, experiment), group = paste(model, experiment, ensemble))) +
  geom_line() +
  labs(x = "Year",
       y = "mol mol-1",
       title = "Atmospheric CO2 over time") +
  theme_minimal()
