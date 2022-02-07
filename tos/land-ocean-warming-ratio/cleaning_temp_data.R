library(ggplot2)
library(tidyr)
library(dplyr)
library(here)

# clean_csv_time:
# Cleans CSV time by making it into year format and if ideal run making the
# years start at 0
# input: 
#     temp_data: data frame with 5 columns (Experiment, Ensemble, Model, 
#                Data, Time, and Temp)
#     upper_year: int - data must be at least up to this year - designed
#                 for an ideal run so will start from 0
# output:
#     temp_data with updated time
clean_csv_time <- function(temp_data, upper_year){
  bad_model <- vector()
  temp_data <- separate(temp_data, "Ensemble_Model", 
                        c("Experiment", "Ensemble", "Model"), "_", 
                        remove = TRUE)
  
  temp_data$Time <- round(temp_data$Time/10000)
  
  unique_ensembles= unique(temp_data$Ensemble)
  unique_models = unique(temp_data$Model)
  
  for(ensemble in unique_ensembles){
    for(model in unique_models){
      model_data <- filter(temp_data, Ensemble == ensemble & Model == model)
      min_year <- min(model_data[,5])
      temp_data$Time <- ifelse((temp_data$Model == model),
                               (temp_data$Time - min_year),
                               temp_data$Time)
      
      model_data <- filter(temp_data, Ensemble == ensemble & Model == model)
      max_year <- max(model_data[,5])
      if(max_year < upper_year){
        print(model)
        bad_model = c(bad_model, model)
      }
      
    }
  }
  for(model in bad_model){
    temp_data <- subset(temp_data, Model != model) 
  }
  temp_data
}

# clean_csv_temp:
# removes any models with temp outside the normal range
# input: 
#       temp_data: data frame with 5 columns (Experiment, Ensemble, Model, 
#                  Data, Time, and Temp)
#       upper_temp: int - max temp data should theoretically be
#       lower_temp: int - min temp data should theoretically be
clean_csv_temp <- function(temp_data, upper_temp, lower_temp){
  bad_data <- filter(temp_data, Temp > upper_temp | Temp < lower_temp)
  bad_models<- unique(bad_data$Model)
  
  for(model in bad_models){
    temp_data <- subset(temp_data, Model != model)   
  }
  
  temp_data
}


### MAIN ###
upper_temp = 300
lower_temp = 270
upper_year = 149  # minimum number of years needed - count from 0
ensemble = 'r1i1p1f1'
path_name = here()
file_name = '1pctCO2_temp.csv'

# Read in CSV Data
temp_data <- read.csv(file = file.path(path_name, file_name),
                      stringsAsFactors = FALSE)

temp_data <- clean_csv_time(temp_data, upper_year)
temp_data<- clean_csv_temp(temp_data, upper_temp, lower_temp)

# Plot to confirm visually that there is no other weird data

ggplot(temp_data, aes(x=Time, y=Temp, group = Model)) + 
  geom_line(aes(color = Model)) +
  facet_grid(cols = vars(Data))

# Write cleaned data to a CSV
write.csv(temp_data, file.path(path_name, paste0('cleaned_', file_name)),
          row.names = FALSE)