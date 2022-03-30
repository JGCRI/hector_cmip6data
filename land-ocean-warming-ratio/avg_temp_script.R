library(plyr)
library(here)

#inputs
path_name = here()
cdo_path = '/share/apps/netcdf/4.3.2/gcc/4.4.7/bin/cdo'
ensembles = c('r1i1p1f1')  # ensembles we will loop over
experiment_type = '1pctCO2'  # experiment type

source(file.path(path_name, 'average_temp_cdo.R'))  # access to functions to calculate annual temperature

# get_usable_models:
# get a list of the models in the given ensemble with temperature data, areacella data, and sftlf data
# inputs:
#       ensemble: the string name of the ensemble we want data from
# outputs:
#       a string vector of the names of the models with all of the needed data to calculate average annual temperature
get_usable_models <- function(ensemble_data){
  tas_models <- unique(ensemble_data [ensemble_data $variable == 'tas' &
                                        ensemble_data$domain == 'Amon' &
                                        ensemble_data$grid != 'gr2' &
                                        ensemble_data$grid != 'gnout1' &
                                        ensemble_data$grid != 'gnout2', ]$model) 
  areacella_models <- unique(ensemble_data [ensemble_data$variable == 'areacella' &
                                              ensemble_data$grid != 'gr2', ]$model) 
  sftlf_models <- unique(ensemble_data [ensemble_data $variable == 'sftlf' &
                                          ensemble_data$grid != 'gr2', ]$model) 
  
  intersect(intersect(tas_models, areacella_models), sftlf_models)
}

# get_file_location:
# given a model and a data type get the path to the file within PIC
# input: data frame of ensemble data
# output: vector of file paths
get_file_location <- function(ensemble_data, model, var){
  model_data <- ensemble_data[c(ensemble_data$model == model & 
                    ensemble_data$variable == var &
                    ensemble_data$grid != 'gr2' &
                      ensemble_data$grid != 'gnout1' &
                      ensemble_data$grid != 'gnout2'),]  # do not want data gridded with 'gr2'
  if (var == 'tas'){
    model_data <- model_data[c(model_data$domain == 'Amon'),]  # only want monthly data, not daily data
  }
  model_data$file  # return the list of files
}


### MAIN ###

# Importing the CMIP6 archive 
archive <- readr::read_csv(url("https://raw.githubusercontent.com/JGCRI/CMIP6/master/cmip6_archive_index.csv"))
experiment_data <- archive[c(archive$experiment == experiment_type & archive$variable %in% c('tas', 'areacella', 'sftlf')),]

df_temps <- data.frame(Ensemble_Model = character(),
                      Data = character(),
                      Time = integer(),
                      Temp = double())


for(e in ensembles){
  ensemble_data <- experiment_data[experiment_data$ensemble == e, ]
  models_with_data <- get_usable_models(ensemble_data)
  
  for(model in models_with_data){
    temp <- get_file_location(ensemble_data, model, 'tas')  # could be a vector if there is more than one tas file for a model
    area <- get_file_location(ensemble_data, model, 'areacella')
    land_frac <- get_file_location(ensemble_data, model, 'sftlf')
    
    ensemble_model = paste0(experiment_type, '_', e, '_', model)
    
    model_path_name <- file.path(path_name, ensemble_model)  # data for each model and ensemble will have its own folder
    dir.create(model_path_name)
    
    df_model <- land_ocean_global_temps(model_path_name, cdo_path, ensemble_model, temp, area, land_frac, TRUE)
    df_temps <- rbind.fill(df_temps, df_model)
  }
}

# write data from all models and ensembles to .csv at path_name
write.csv(df_temps, file.path(path_name, paste0(experiment_type, '_temp.csv')), row.names = FALSE)

