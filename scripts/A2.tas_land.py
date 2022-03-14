# ------------------------------------------------------------------------------
# Program Name: A2.tas_land.py
# Authors: Leeya Pressburger
# Date Last Modified: March 2022
# Program Purpose: Downloads CMIP6 `tas` data using Pangeo, coarsens monthly data
# to an annual mean, calculates surface temperature over land
# Outputs: One csv file with annual tas-over-land data for every specified CMIP6
# model, experiment, and ensemble run saved as "model_experiment_ensemble.csv"
# TODO:
# ------------------------------------------------------------------------------

# Import packages
import fsspec
import intake
import numpy as np
import pandas as pd
import xarray as xr
import session_info
import cftime

# Display all columns in dataframe
pd.set_option('display.max_columns', None)

# Helper functions from stitches project - data processing
# https://github.com/JGCRI/stitches/blob/mega_cleanup/stitches/fx_data.py#L29

def get_ds_meta(ds):
    """ Get the meta data information from the xarray data set.
    :param ds:  xarray dataset of CMIP data.
    :return:    pandas dataset of MIP information.
    """
    v = ds.variable_id

    data = [{'variable':v,
             'experiment':ds.experiment_id,
             'units':ds[v].attrs['units'],
            'frequency': ds.attrs["frequency"],
             'ensemble':ds.attrs["variant_label"],
             'model': ds.source_id}]
    df = pd.DataFrame(data)

    return df

# https://github.com/JGCRI/stitches/blob/mega_cleanup/stitches/fx_pangeo.py
# Define the functions that are useful for working with the pangeo data base
# see https://pangeo.io/index.html for more details.

def fetch_pangeo_table():
    """ Get a copy of the pangeo archive contents
    :return: a pd data frame containing information about the model, source, experiment, ensemble and
    so on that is available for download on pangeo.
    """

    # The url path that contains to the pangeo archive table of contents.
    url = "https://storage.googleapis.com/cmip6/pangeo-cmip6.json"
    out = intake.open_esm_datastore(url)

    return out.df


def combine_df(df1, df2):
    """ Join the data frames together.
    :param df1:   pandas data frame 1.
    :param df2:   pandas data frame 2.
    :return:    a single pandas data frame.
    """

    # Combine the two data frames with one another.
    df1["j"] = 1
    df2["j"] = 1
    out = df1.merge(df2)
    out = out.drop(columns="j")

    return out

def selstr(a, start, stop):
    """ Select elements of a string from an array.
    :param a:   array containing a string.
    :param start: int referring to the first character index to select.
    :param stop: int referring to the last character index to select.
    :return:    array of strings
    """
    if type(a) not in [str]:
        raise TypeError(f"a: must be a single string")

    out = []
    for i in range(start, stop):
        out.append(a[i])
    out = "".join(out)
    return out

# End of helper functions

def get_land_tas(path):
    """ For a pangeo file, calculate the area weighted surface temperature mean over land.
    :param path:  str of the location of the cmip6 data file on pangeo
    :return:      csv file of output data
    """
    ds = xr.open_zarr(fsspec.get_mapper(path), consolidated=True)
    df = pd.read_csv('https://storage.googleapis.com/cmip6/cmip6-zarr-consolidated-stores.csv')

    # Extract the meta data
    meta_data = get_ds_meta(ds)

    # Based on the meta data find the correct areacella file
    query1 = "variable_id == 'areacella' & source_id == '" + meta_data.model[0] + "'"
    if df_area.shape[0] < 1:
        raise RuntimeError("Could not find areacella for " + path)
    query2 = "variable_id == 'sftlf' & source_id == '" + meta_data.model[0] + "'"
    if df_landper.shape[0] < 1:
        raise RuntimeError("Could not find sftlf for " + path)

    df_area = df.query(query1)
    if df_area.shape[0] < 1:
        raise RuntimeError("Could not find areacella for " + path)
    df_landper = df.query(query2)
    if df_landper.shape[0] < 1:
        raise RuntimeError("Could not find sftlf for " + path)

    df_area = df.query(query1)
    df_landper = df.query(query2)

    # Read in the area cella file
    ds_area = xr.open_zarr(fsspec.get_mapper(df_area.zstore.values[0]), consolidated=True)
    ds_landper = xr.open_zarr(fsspec.get_mapper(df_landper.zstore.values[0]), consolidated=True)

    # Select only the land cell area values, use this mask as the area weights.
    mask = 1 * (ds_area['areacella'] * (0.01 * ds_landper['sftlf']))
    # Replace 0 and 1 with NA
    mask = xr.where(mask == 0, np.nan, mask)
    masked_area = ds_area * mask

    # Using the land cell area and total area calculate the weighted mean over the land.
    total_area = masked_area.areacella.sum(set(masked_area.areacella.dims), skipna=True)
    other_dims = set(ds.tas.dims) - {'time'}

    # Weighted average calculation
    wa = (ds.tas * masked_area.areacella).sum(dim=other_dims) / total_area
    wa = wa.coarsen(time=12, boundary="trim").mean()

    # Extract time information.
    t = wa["time"].dt.strftime("%Y%m%d").values
    year = list(map(lambda x: selstr(x, start=0, stop=4), t))

    # Format into a data frame.
    val = wa.values
    d = {'year': year, 'value': val}
    df = pd.DataFrame(data=d)
    out = combine_df(meta_data, df)

    name = out["model"][0] + "_" + out["experiment"][0] + "_" + out["ensemble"][0]
    # Save as csv
    out.to_csv(name + ".csv", header=True, index=True)

# Access Pangeo files
dat = fetch_pangeo_table()

# Pull out specifics
exps = ['1pctCO2', 'abrupt-4xCO2', 'abrupt-2xCO2', 'esm-hist', 'esm-ssp585', 'ssp119',
        'ssp126', 'ssp245', 'ssp370', 'ssp434', 'ssp460', 'ssp585', 'historical']

mips = ['CMIP', 'ScenarioMIP']

fails = ["BCC-CSM2-MR", "AWI-CM-1-1-MR", "NUIST/NESM3", "MCM-UA-1-0",
"NorESM2-LM", "FGOALS-g3", "FGOALS-f3-L", "KACE-1-0-G", "GISS-E2-2-G", 
"IITM-ESM", "FIO-ESM-2-0", "THU/CIESM", "CCR-IITM", "IPSL-C5A2-INCA", 
"ICON-ESM-LR", "KIOST-ESM"]

# Access desired zstore addresses
address_all = dat[(dat['variable_id'] == 'tas') & (dat['experiment_id'].isin(exps)) &
                   (dat['table_id'] == 'Amon') & (dat['activity_id'].isin(mips)) &
                   (~dat['source_id'].isin(fails))].zstore

address_all = address_all.reset_index(drop=True)

# Loop
for items in address_all:
    get_land_tas(items)

session_info.show()
