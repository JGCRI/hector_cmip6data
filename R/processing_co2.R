library(readr)
library(dplyr)
library(ggplot2)
library(ncdf4)
library(here)

# Set directory, read in files
BASE_DIR <- here::here()
path = paste0(BASE_DIR, "/co2")

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
co2 <- left_join(data, years, by = "rownum")

# Problem - need to make one year column with "year" and "new_year"
# If new_year has an NA, replace it with year, otherwise leave as is
replace_year <- ifelse(is.na(co2$new_year), 
                       co2$year, 
                       co2$new_year)

co2$year <- replace_year

# Get rid of unnecessary columns
co2 <- co2 %>% select(c(-new_year, -File.y, -X1))


plot <- co2 %>% 
  ggplot(aes(year, value, color = paste(model, experiment), group = paste(model, experiment, ensemble))) +
  geom_line() +
  facet_wrap(~experiment, scales = "free_x") +
  labs(x = "Year",
       y = "mol mol-1",
       title = "Atmospheric CO2 over time") +
  theme_minimal()

no_facet <- co2 %>%
  ggplot(aes(year, value, color = paste(model, experiment), group = paste(model, experiment, ensemble))) +
  geom_line() +
  labs(x = "Year",
       y = "mol mol-1",
       title = "Atmospheric CO2 over time") +
  theme_minimal()

