The contents of this directory are used to get process the tos data stored on pangeo into the values needed by the hector ocean component which include a pre-industrial average tos for the entire ocean as well as the average for the HL and LL regions. Note the scripts are labeled in order they should be run, L0 scripts should be run before L1 & L2 scripts. To keep the size of the repository small only the outputs from the L1 and L2 scripts are committed to the repository. 

**Part 1**
Python scripts that process CMIP6 netcdf files stored on pangeo. Will need to be run in python. 

     * 0.global_tos.py – get the monthly mean global ocean tos values from the historical CMIP6 results. 
     * 0.HL_tos.py – get the monthly mean ocean tos values for the HL region (latitude > 55) from the historical CMIP6 results.
     * 0.LL_tos.py - get the monthly mean ocean tos values for the LL region (latitude < 55) from the historical CMIP6 results.

**Part 2**
Scripts to be run in R to quality check data & calculate the values to be used by the Hector component. 

    * 1.postprocessing.R – R script that checks the quality of data, if there are files missing years, potential problems with units, and make sure that the subset of data for each region uses results from the same model & ensemble member. 
    * 2.get_hector_data.Rmd – R script that from the tos results calculates the actual values that will be used as Hector inputs. 






