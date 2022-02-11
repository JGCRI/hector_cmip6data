library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ncdf4)
library(here)

BASE_DIR <- here::here()

vars <- c("hfls", "hfss", "rlds", "rlus", "rsds", "rsus")

get_path <- function(var){
  assign(x = paste0("path_", var), 
         value = file.path(BASE_DIR, "heat_flux", var))
}

paths <- lapply(vars, get_path)
paths <- c(paths[[1]], paths[[2]], paths[[3]], paths[[4]], paths[[5]], paths[[6]])

list_files <- function(path){
  list.files(path = path, pattern = "*.csv", full.names = TRUE)
}

files <- lapply(paths, list_files)

# Read in data, forcing column types
output <- list()

for(num in 1:length(files)){
  output[[num]] <- lapply(files[[num]], read_csv, col_types = "dccccccdd") %>%
    bind_rows(.id = "File")
}

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

group_by_var <- new_output %>%
  group_by(variable) %>%
  summarize(names = unique(name)) %>%
  mutate(count = length(names))

counts <- unique(group_by_var$count)

# Which variables have the most and least names?
most_names <- group_by_var %>% filter(variable == "hfls")
least_names <- group_by_var %>% filter(variable == "rlds")

# Extract common names and names that are missing
### TO DO - make sure all names are the same for all variables
common_names <- left_join(most_names, least_names, by = "names")
common_names <- drop_na(common_names)
good_names <- common_names$names

bad_names <- new_output %>% 
  filter(!name %in% good_names)
bad_names <- unique(bad_names$name)
bad_names <- bad_names[1:8]

# Reorganize data frame
data <- new_output %>%
  filter(variable != "NA") %>%
  # Remove missing names
  filter(!name %in% bad_names) %>%
  select(-c("X1", "x", "File.x", "File.y")) %>%
  relocate(c("rownum", "name"), .before = "variable")

### make sure this works
# Problem - need to make one year column with "year" and "new_year"
# If new_year has an NA, replace it with year, otherwise leave as is
replace_year <- ifelse(is.na(data$new_year), 
                data$year, 
                data$new_year)
data$year <- replace_year
data <- data %>% select(-new_year)

### TO DO
# Heat flux equation
# rsds - rsus + rlds - rlus - hfss - hfls
# For each name and year, manipulate values of these data sets

rsds <- data %>% filter(variable == "rsds")
rsus <- data %>% filter(variable == "rsus")
rlds <- data %>% filter(variable == "rlds")
rlus <- data %>% filter(variable == "rlus")         
hfss <- data %>% filter(variable == "hfss")
hfls <- data %>% filter(variable == "hfls")

test <- data %>% select(c(name, variable, year, value))

