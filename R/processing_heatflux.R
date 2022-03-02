library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)

BASE_DIR <- here::here()

# Variables of interest
vars <- c("hfls", "hfss", "rlds", "rlus", "rsds", "rsus")

# Function to get lists of file paths for each of the six variables
get_path <- function(var){
  assign(x = paste0("path_", var), 
         value = file.path(BASE_DIR, "heat_flux", var))
}

paths <- lapply(vars, get_path)
paths <- c(paths[[1]], paths[[2]], paths[[3]], paths[[4]], paths[[5]], paths[[6]])

# Function to list the files for each path specified
list_files <- function(path){
  list.files(path = path, pattern = "*.csv", full.names = TRUE)
}

files <- lapply(paths, list_files)

# Read in data, forcing column types
output <- list()

# For each file in each file path for each variable, read in the csv data
for(num in 1:length(files)){
  output[[num]] <- lapply(files[[num]], read_csv, col_types = "dccccccdd") %>%
    bind_rows(.id = "File")
}

# Create data frame
output <- bind_rows(output)

# Add name and row number identifiers
output$name <- paste0(output$model, "_", 
                      output$ensemble, "_", 
                      output$experiment)

output$rownum <- seq_len(nrow(output))

# Correct non-conventional years
output1 <- output %>%
  select("rownum", "year", "File") %>%
  filter(year < 1850 | year > 2500) %>%
  group_by(File) %>%
  mutate(start_year = year[1],
         scale = year - start_year,
         new_year = 1850 + scale) %>%
  select("rownum", "new_year")

# Combine with original dataframe
new_output <- left_join(output, output1, by = "rownum")

# Need to get common names across six variables
names <- unique(new_output$name)

# How many model/experiment/ensemble combinations are there for each variable?
group_by_var <- new_output %>%
  group_by(variable) %>%
  summarize(names = unique(name)) %>%
  mutate(count = length(names))

counts <- group_by_var %>% summarize(variable, count) %>% unique()

# Which variables have the most and least names?
most_names <- group_by_var %>% filter(variable == "rsds")
hfls_names <- group_by_var %>% filter(variable == "hfls")
hfss_names <- group_by_var %>% filter(variable == "hfss")
rlds_names <- group_by_var %>% filter(variable == "rlds")
rlus_names <- group_by_var %>% filter(variable == "rlus")
rsus_names <- group_by_var %>% filter(variable == "rsus")

# Extract common names and names that are missing
common_names <- left_join(most_names, hfls_names, by = "names")
common_names <- left_join(common_names, hfss_names, by = "names")
common_names <- left_join(common_names, rlds_names, by = "names")
common_names <- left_join(common_names, rlus_names, by = "names")
common_names <- left_join(common_names, rsus_names, by = "names")
common_names <- drop_na(common_names)

good_names <- common_names$names
good_names <- good_names[-337]

# Reorganize data frame
data <- new_output %>%
  # Remove pesky NA variable
  filter(variable != "NA") %>%
  # Remove missing names
  filter(name %in% good_names) %>%
  # Organize
  select(-c("X1", "x", "File.x", "File.y")) %>%
  relocate(c("rownum", "name"), .before = "variable")

# Problem - need to make one year column with "year" and "new_year"
# If new_year has an NA, replace it with year, otherwise leave as is
replace_year <- ifelse(is.na(data$new_year), 
                data$year, 
                data$new_year)
data$year <- replace_year
# Get rid of new_year column
data <- data %>% select(-new_year)

# Heat flux equation
# rsds - rsus + rlds - rlus - hfss - hfls

# Select important columns
heat_flux <- data %>% select(c(name, year, variable, value))

# Reshape data
heat_flux <- heat_flux %>%
  group_by(name, year) %>%
  pivot_wider(names_from = variable, values_from = value, values_fn = list) %>%
  ungroup()

# Compute equation
hf_output <- list()
for(n in seq_len(nrow(heat_flux))){
  hf_output[[n]] <- heat_flux$rsds[[n]] - heat_flux$rsus[[n]] + 
    heat_flux$rlds[[n]] - heat_flux$rlus[[n]] - 
    heat_flux$hfss[[n]] - heat_flux$hfls[[n]]
}

hf_output <- as.numeric(as.charachter(hf_output))

# Combine list with data frame
heat_flux <- heat_flux %>%
  mutate(equation = hf_output)

# Data visualization in the corresponding Rmd