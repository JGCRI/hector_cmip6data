# ------------------------------------------------------------------------------
# Program Name: A4.heatflux_preprocessing.py
# Authors: Leeya Pressburger
# Date Last Modified: March 2022
# Program Purpose: Accessing netCDF file locations for all heatflux variables:
# hfls, hfss, rlds, rlus, rsds, rsus
# Additional processing is required in R: ./scripts/B4a.heatflux_preprocessing.R
# TODO:
# ------------------------------------------------------------------------------

# Import packages
import intake
import pandas as pd


def fetch_pangeo_table():
    """ Get a copy of the pangeo archive contents
    :return: a pd data frame containing information about the model, source, experiment, ensemble and
    so on that is available for download on pangeo.
    """

    # The url path that contains to the pangeo archive table of contents.
    url = "https://storage.googleapis.com/cmip6/pangeo-cmip6.json"
    out = intake.open_esm_datastore(url)

    return out.df

# Get Pangeo table
dat = fetch_pangeo_table()

# Accessing data
# Isolate heat flux variables
vars = ['rsds', 'rsus', 'rlds', 'rlus', 'hfss', 'hfls']
exps = ['1pctCO2', 'abrupt-4xCO2', 'abrupt-2xCO2', 'esm-hist', 'esm-ssp585', 'ssp119',
        'ssp126', 'ssp245', 'ssp370', 'ssp434', 'ssp460', 'ssp585']
mips = ['CMIP', 'ScenarioMIP']
fails = ['BCC-CSM2-MR', 'AWI-CM-1-1-MR', 'NUIST/NESM3', 'NorESM2-LM', 
'FGOALS-g3', 'FGOALS-f3-L', 'KACE-1-0-G', 'GISS-E2-2-G', 'CCCR-IITM', 
'THU/CIESM', 'CAS-ESM2-0', 'FIO-ESM-2-0']

# Pull info for variables and experiments of interest
data = dat[(dat['variable_id'].isin(vars)) & (dat['experiment_id'].isin(exps)) &
           (dat['table_id'] == 'Amon') & (dat['activity_id'].isin(mips)) &
           (~dat['source_id'].isin(fails))]

data = data.reset_index(drop = True)

# Create name identifier
data['name'] = data['source_id'] + "/" + data['experiment_id'] + "/" + data['member_id']
data.to_csv("./inputs/heatflux_addresses.csv", header=True, index=True)
