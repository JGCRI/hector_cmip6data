library(readr)
library(dplyr)
library(ggplot2)
library(ncdf4)

mypath = "C:/Users/pres520/PycharmProjects/pangeo/test"

files <- list.files(path = mypath, pattern = "*.csv", full.names = TRUE)

# Remove non-model run - "/pangeo_table.csv"
nums <- c(1:956, 958:1045)
files <- files[nums]

# Read in data, forcing column types
data <- lapply(files, read_csv, col_types = "dccccccdd") %>%
  bind_rows(.id = "File")

# Add name identifier
data$name <- paste0(data$model, "_", data$ensemble, "_", data$variable)

## Get historical average
testing <- data %>%
  filter(experiment == "historical") %>%
  group_by(model) %>%
  mutate(hist_av = mean(value))

historical <- as.data.frame(unique(testing$model))
historical$avg <- unique(testing$hist_av)
colnames(historical) <- c("model", "avg")

## Get Tgav
models <- historical$model
Tgav <- data %>%
  filter(model %in% models, !experiment == "historical") %>%
  left_join(historical, by = "model") %>%
  mutate(Tgav = value - avg)

# Non-conventional year numbering
weird_range <- data %>% filter(year < 1850 | year > 2500)
weird_range <- weird_range %>% mutate(ncdf = paste0(model, "_", ensemble, "_", experiment))
weird_models <- unique(weird_range$name)
model_ncdf <- as.data.frame(unique(weird_range$ncdf))
colnames(model_ncdf) <- "model"

# Normal years (1850-2100)
normal_range <- data %>% filter(year > 1849 & year < 2500)

plot_normal <- normal_range %>% 
  ggplot(aes(year, value, color = model, group = paste(model, experiment, ensemble))) +
  geom_line() +
  facet_wrap(~experiment, scales = "free_x") +
  labs(x = "Year",
       y = "tas",
       title = "CMIP6 runs - tas over time") +
  theme_minimal()

co2 <- co2exp <- normal_range %>% filter(experiment %in% c("1pctCO2", "abrupt-2xCO2", "abrupt-4xCO2"))

hist <- normal_range %>% filter(experiment == "historical")

ssps <- normal_range %>% filter(experiment %in% c("ssp119", "ssp126", "ssp245", "ssp370", "ssp434", "ssp460", "ssp534-over", "ssp585"))

plot_co2 <- co2exp %>%
  ggplot(aes(year, value, color = experiment, group = paste(model, experiment, ensemble))) +
  geom_line() +
  labs(x = "Year",
       y = "tas",
       title = "CMIP6 runs - tas over time") +
  facet_wrap(~model) +
  theme_minimal()

plot_hist <- hist %>%
  ggplot(aes(year, value, color = experiment, group = paste(model, experiment, ensemble))) +
  geom_line() +
  labs(x = "Year",
       y = "tas",
       title = "CMIP6 runs - tas over time") +
  facet_wrap(~model) +
  theme_minimal()

plot_ssps <- ssps %>%
  ggplot(aes(year, value, color = experiment, group = paste(model, experiment, ensemble))) +
  geom_line() +
  labs(x = "Year",
       y = "tas",
       title = "CMIP6 runs - tas over time") +
  facet_wrap(~model) +
  theme_minimal()


