library(readr)
library(dplyr)
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

# Heat flux equation
# rsds - rsus + rlds - rlus - hfss - hfls

# Need to get common names across six variables
names <- unique(new_output$name)

group_by_var <- new_output %>%
  group_by(variable) %>%
  summarize(names = unique(name)) %>%
  mutate(count = length(names))

counts <- unique(group_by_var$count)

most_names <- group_by_var %>% filter(variable == "hfss")
small_names <- c(least_names$names)
least_names <- group_by_var %>% filter(variable == "rlus")

common_names <- group_by_var %>%
  filter(names == small_names)
