# ------------------------------------------------------------------------------
# Program Name: A5.rh.py
# Authors: Leeya Pressburger
# Date Last Modified: March 2022
# Program Purpose: Downloads CMIP6 `rh` data using Pangeo, calculates values over
# land only, coarsens monthly data to an annual mean
# Outputs: One csv file with annual rh data for every specified CMIP6
# model, experiment, and ensemble run saved as "model_experiment_ensemble.csv"
# Output units are kg m-2 s-1 and will be converted to Pg/gridcell/yr in
# B5.processing_rh.R
# TODO:
# ------------------------------------------------------------------------------

# Import packages
import fsspec
import intake
import pandas as pd
import xarray as xr
import session_info

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

def get_land_rh(path):
    """ For a pangeo file, calculate the area weighted heterotrophic respiration over land.

    :param path:  str zstore path corresponding to a pangeo netcdf

    :return:      pandas.core.frame.DataFrame of area-weighted land rh from a single netcdf file
    """
    ds = xr.open_zarr(fsspec.get_mapper(path), consolidated=True)
    df = pd.read_csv('https://storage.googleapis.com/cmip6/cmip6-zarr-consolidated-stores.csv')

    # Extract the meta data
    meta_data = get_ds_meta(ds)

    # Based on the meta data find the correct areacella file
    query1 = "variable_id == 'areacella' & source_id == '" + meta_data.model[0] + "'"
    query2 = "variable_id == 'sftlf' & source_id == '" + meta_data.model[0] + "'"

    df_area = df.query(query1)
    df_landper = df.query(query2)

    # Read in the area cella file
    ds_area = xr.open_zarr(fsspec.get_mapper(df_area.zstore.values[0]), consolidated=True)
    ds_landper = xr.open_zarr(fsspec.get_mapper(df_landper.zstore.values[0]), consolidated=True)

    # Select only the land cell area values, use this mask as the area weights.
    mask = 1 * (ds_area['areacella'] * (0.01 * ds_landper['sftlf']))

    # Using the land cell area calculate the weighted mean over the land.
    land_area = mask.values.sum()
    other_dims = set(ds.rh.dims) - {'time'}

    # Weighted average calculation
    wa = (ds.rh * mask).sum(dim=other_dims) / land_area
    # Annual average
    wa = wa.coarsen(time=12, boundary="trim").mean()

    # Extract time information.
    t = wa["time"].dt.strftime("%Y%m%d").values
    year = list(map(lambda x: selstr(x, start=0, stop=4), t))

    # Format into a data frame.
    val = wa.values
    d = {'year': year, 'value': val}
    df = pd.DataFrame(data=d)
    out = combine_df(meta_data, df)
    out['land_area'] = land_area

    name = out["model"][0] + "_" + out["experiment"][0] + "_" + out["ensemble"][0]
    # Save as csv
    out.to_csv(name + ".csv", header=True, index=True)

# Access Pangeo files
dat = fetch_pangeo_table()

# Pull out specifics
exps = ['1pctCO2', 'abrupt-4xCO2', 'abrupt-2xCO2', 'esm-hist', 'esm-ssp585', 'ssp119',
        'ssp126', 'ssp245', 'ssp370', 'ssp434', 'ssp460', 'ssp585', 'historical']

mips = ['CMIP', 'ScenarioMIP']

# Access desired zstore addresses
# Note that the removed model does not contain areacella or sftlf values and is therefore pulled out
address_all = dat[(dat['variable_id'] == 'rh') & (dat['experiment_id'].isin(exps)) &
                   (dat['table_id'] == 'Lmon') & (dat['activity_id'].isin(mips)) &
                  (dat['source_id'] != 'BCC-CSM2-MR')].zstore

address_all = address_all.reset_index(drop=True)

# Loop
for items in address_all:
    get_land_rh(items)

session_info.show()
