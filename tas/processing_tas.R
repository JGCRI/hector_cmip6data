library(readr)
library(dplyr)
library(ggplot2)
library(ncdf4)
library(here)

BASE_DIR <- here::here()

mypath <-  "C:/Users/pres520/PycharmProjects/pangeo/test/tas"
path1 <- file.path(BASE_DIR, "csv1")
path2 <- file.path(BASE_DIR, "csv2")

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
model_ncdf <- model_ncdf %>% mutate(filename = paste0(mypath, "/", model, ".nc"))

# We want to open net cdf file, extract time information, and loop to normalize
results <- lapply(model_ncdf$filename, nc_open)
output <- list()
for(d in c(1:42)) {
  output[[d]] <- results[[d]]$dim$time$units
}

# Okay, we have different start years. Let's make them all start at 0
test <- tibble(name = weird_models,
               output = output[1:42],
               start_year = c(950, 950, 101, 101, 101, 3030, 3030, 3035, 3035,
                              200, 0001, 0001, 0001, 0001, 0001, 0001, 0001,
                              0001, 0001, 0001, 0370, 0463, 0300, 0699, 0001,
                              0001, 0001, 0001, 0001, 0001, 2900, 3200, 3200, 
                              3200, 0001, 0001, 0001, 0001, 0001, 0001, 0001, 0001))

test <- test %>% mutate(start = start_year - start_year)

new_data <- left_join(weird_range, test, by = "name") %>%
  mutate(start = year - start_year)

# Final dataset
final_data <- left_join(Tgav, new_data, by = "name")


### Graphs and notes
## Plot results

# Normal years (1850-2500)
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

new_plot <- new_data %>% 
  ggplot(aes(year, value, color = model, group = paste(model, experiment, ensemble))) +
  geom_line() +
  facet_wrap(~experiment, scales = "free_x") +
  labs(x = "Year (relative to base year)",
       y = "tas",
       title = "CMIP6 runs - tas over time") +
  theme_minimal()

##  Notes
## Fix dates
# Extract and format output time results. 
# Arguments 
#   nc: the nc data of the file with the time information to extract. 
# Returns: A data frame of the time formated as time date information. 
format_time <- function(nc){
  
  nc <- nc_open(nc)
  
  # Make sure that the object being read in is a netcdf file.
  # assertthat::assert_that(class(nc) == "ncdf4")
  
  # Convert from relative time to absolute time using lubridate.
  time_units <- ncdf4::ncatt_get(nc, 'time')$units
  time_units <- gsub(pattern = 'days since ', replacement = '', time_units)
  time_units <- gsub(pattern = 'hours since ', replacement = '', time_units)
  time <- lubridate::as_date(ncdf4::ncvar_get(nc, 'time'), origin = time_units)
  
  data.frame(datetime = time,
             year = lubridate::year(time),
             month = lubridate::month(time),
             stringsAsFactors = FALSE)
  
}
