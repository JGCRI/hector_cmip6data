library(readr)
library(dplyr)
library(ggplot2)
library(ncdf4)
library(here)

BASE_DIR <- here::here()

path1 <- paste0(BASE_DIR, "/tas/csv1")
path2 <- paste0(BASE_DIR, "/tas/csv2")

files1 <- list.files(path = path1, pattern = "*.csv", full.names = TRUE)
files2 <- list.files(path = path2, pattern = "*.csv", full.names = TRUE)

# Read in data, forcing column types
data1 <- lapply(files1, read_csv, col_types = "dccccccdd") %>%
  bind_rows(.id = "File")

data2 <- lapply(files2, read_csv, col_types = "dccccccdd") %>% 
  bind_rows(.id = "File")

data <- bind_rows(data1, data2)

# Add name identifier
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

## Get historical average
histo <- tas %>%
  filter(experiment == "historical") %>%
  group_by(model) %>%
  mutate(hist_av = mean(value))

historical <- as.data.frame(unique(histo$model))
historical$avg <- unique(histo$hist_av)
colnames(historical) <- c("model", "avg")

## Get Tgav
models <- historical$model
Tgav <- tas %>%
  filter(model %in% models, !experiment == "historical") %>%
  left_join(historical, by = "model") %>%
  mutate(Tgav = value - avg)

### Graphs and notes
## Plot results
plot_t <- Tgav %>% 
  ggplot(aes(year, value, color = model, group = paste(model, experiment, ensemble))) +
  geom_line() +
  facet_wrap(~experiment, scales = "free_x") +
  labs(x = "Year",
       y = "tas",
       title = "CMIP6 runs - tas over time") +
  theme_minimal()

co2exp <- tas %>% filter(experiment %in% c("1pctCO2", "abrupt-2xCO2", "abrupt-4xCO2"))

hist <- tas %>% filter(experiment == "historical")

ssps <- tas %>% filter(experiment %in% c("ssp119", "ssp126", "ssp245", "ssp370", "ssp434", "ssp460", "ssp534-over", "ssp585"))

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
