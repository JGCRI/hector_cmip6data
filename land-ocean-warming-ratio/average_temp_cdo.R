library(ncdf4)
library(ggplot2)
library(dplyr)

#get_weighted_area:
#Calculates and saves the fraction of each grid that is land and ocean in decimal form (max 1, min 0) and saves both as .nc files at the specificed path_name
#inputs:
#     land_frac: .nc file location that contains fraction of grid that is land (either in decimal or percent)
#     land_area: .nc file location that will contain the area of each gris square weighted by the percent of the grid that is land
#     ocean_frac: .nc file location that will contain the area of each gris square weighted by the percent of the grid that is
#     cleanup: a boolean value - if true than intermediate files will be deleted - defaults to true

get_weighted_areas <- function(land_frac, path_name, land_area, ocean_area, cleanup = TRUE){
  
  nc_open(land_frac) %>% ncvar_get('sftlf') %>% max(na.rm = FALSE) -> max_frac
  
  if(max_frac > 1){
    land_frac_dec <- file.path(path_name, paste0(ensemble_model,"_land_frac.nc"))
    system2(cdo_path, args = c('divc,100', land_frac, land_frac_dec))
    land_frac <- land_frac_dec
  }
  
  ocean_frac <- file.path(path_name, paste0(ensemble_model,'_ocean_frac.nc'))
  system2(cdo_path, args = c('-mulc,-1', '-addc,-1', land_frac, ocean_frac), stdout = TRUE, stderr = TRUE)
  
  #calculates weighted area
  system2(cdo_path, args = c('mul', area, land_frac, land_area), stdout = TRUE, stderr = TRUE)
  system2(cdo_path, args = c('mul', area, ocean_frac, ocean_area), stdout = TRUE, stderr = TRUE)
  
  if(cleanup){
    file.remove(ocean_frac)
    if(exists('land_frac_dec')){  # if it doesn't exist this is original sftlf data, which we don't want to delete
      file.remove(land_frac)
    }
  }
}

# get_annual_temp:
# Calculates the annual temp based on the weighting .nc file passed into the function and saves the annual average temp in a .nc file at path_name
# inputs: 
#     weight_area: .nc file location that contains the weighted area of each grid square
#     t: .nc file name of the temperature file that is being used (necessary due to some models having several tas files)
#     annual_temp: .nc file location that will contain the weighted average temperature over the data's time steps
#     counter: int value signifying which tas file we are on for this model (used to make more specific file names since cdo doesn't over write files)
#     type: string signifying which type of temperature we are calculating (land, ocean, or global), again used to make file names more specific
#     cleanup: a boolean value - if true than intermediate files will be deleted - defaults to true

get_annual_temp <- function(weight_area, t, path_name, annual_temp, counter, type, cleanup = TRUE){
  assertthat::assert_that(file.exists(weight_area))
  
  if(!file.exists(annual_temp)){
    
    #file to be created
    combo <-file.path(path_name, paste0(ensemble_model,'_combo_weight_temp_', type, '_', counter, '.nc'))  # temp and weighted area parameteres in same netCDF files so weighted mean can be calculated
    month_temp <- file.path(path_name, paste0(ensemble_model,'_month_temp_', type, '_', counter, '.nc'))
    
    #calculates weighted average temperature for each timestep and converts monthly data to yearly average
    system2(cdo_path, args = c('merge', t, weight_area, combo), stdout = TRUE, stderr = TRUE)
    system2(cdo_path, args = c('fldmean', combo, month_temp), stdout = TRUE, stderr = TRUE)
    system2(cdo_path, args = c('-a', 'yearmonmean', month_temp, annual_temp), stdout = TRUE, stderr = TRUE) #Might be able to combine on PIC -> seg fault rn
    
    if(cleanup){
      file.remove(combo)
      file.remove(month_temp)
    }
  }
}


# land_ocean_temps:
# Calculates average annual temperatures for land, ocean, and global
# Inputs:
#       path_name: path to a folder where the output .nc files will be stored
#       cdo_path: path to where the cdo.exe is located on the local computer
#       ensemble_model: string of ensemble and model run to create more specific file names
#       temp: .nc file location that contains the monthly temperature data (could be a vector of several .nc files depending on model)
#       area: .nc file location that contains the area of each grid cell 
#       land_fac: .nc file location that contains the percent of each grid cell that is land
# Outputs:
#       A data frame of the model's land, ocean, and global average annual temperature data

land_ocean_global_temps <- function(path_name, cdo_path, ensemble_model, temp, area, land_frac, cleanup = TRUE){
  assertthat::assert_that(file.exists(area))
  assertthat::assert_that(file.exists(land_frac))
  
  land_area <-  file.path(path_name, paste0(ensemble_model, '_land_area.nc'))
  ocean_area <- file.path(path_name, paste0(ensemble_model, '_ocean_area.nc'))
  
  get_weighted_areas(land_frac, path_name, land_area, ocean_area, cleanup)
  
  df_model <- data.frame(Ensemble_Model = character(),
                         Data = character(),
                         Time = integer(),
                         Temp = double())
  
  counter = 1;  # keeps track of which tas file we are on within temp
  
  # loops through all of the .nc tas file if there are more than one for a singular model
  for (t in temp){
    assertthat::assert_that(file.exists(t))
    
    land_temp <- file.path(path_name, paste0(ensemble_model, '_land_temp_', counter, '.nc'))
    ocean_temp <- file.path(path_name, paste0(ensemble_model, '_ocean_temp_', counter, '.nc'))
    global_temp <- file.path(path_name, paste0(ensemble_model, '_global_temp_', counter, '.nc'))
    
    get_annual_temp(land_area, t, path_name, land_temp, counter, 'land', cleanup)
    get_annual_temp(ocean_area, t, path_name, ocean_temp, counter, 'ocean', cleanup)
    get_annual_temp(area, t, path_name, global_temp, counter, 'global', cleanup)
    
    nc_open(land_temp) %>% ncvar_get("tas") -> land_tas
    nc_open(ocean_temp) %>% ncvar_get("tas") -> ocean_tas
    nc_open(global_temp) %>% ncvar_get("tas") -> global_tas
    nc_open(land_temp) %>% ncvar_get("time") -> time
    
    temp_frame <- data.frame(Ensemble_Model = rep(ensemble_model, dim(time)),
                             Data = rep(c("Land", "Ocean", "Global"), each = dim(time)),
                             Time = rep(time, 3),
                             Temp = c(land_tas, ocean_tas, global_tas))
    
    # bind each of the tas files for model into one data frame
    df_model <- rbind.fill(df_model, temp_frame)
    counter = counter + 1;
    
    if(cleanup){
      file.remove(land_temp)
      file.remove(ocean_temp)
      file.remove(global_temp)
    }
  }
  
  if(cleanup){
    file.remove(land_area)
    file.remove(ocean_area)
  }
  
  # write the data for this model and return the model's data frame
  write.csv(df_model,  file.path(path_name, paste0(ensemble_model, '_temp.csv')), row.names = FALSE)
  df_model
}





