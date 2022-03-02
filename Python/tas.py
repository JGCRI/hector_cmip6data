# Processing CMIP6 tas data using Pangeo
# December 2021
# Leeya Pressburger

# Import packages
import fsspec
import intake
import numpy as np
import pandas as pd
import xarray as xr

# Display all columns in dataframe
pd.set_option('display.max_columns', None)

# Helper functions from stitches project - data processing
# https://github.com/JGCRI/stitches/blob/mega_cleanup/stitches/fx_data.py#L29

def get_lat_name(ds):
    """ Get the name for the latitude values (could be either lat or latitude).
    :param ds:    xarray dataset of CMIP data.
    :return:    the string name for the latitude variable.
    """
    for lat_name in ['lat', 'latitude']:
        if lat_name in ds.coords:
            return lat_name
    raise RuntimeError("Couldn't find a latitude coordinate")

def global_mean(ds):
    """ Get the weighted global mean for a variable.
    :param ds:  xarray dataset of CMIP data.
    :return:    xarray dataset of the weighted global mean.
    """
    lat = ds[get_lat_name(ds)]
    weight = np.cos(np.deg2rad(lat))
    weight /= weight.mean()
    other_dims = set(ds.dims) - {'time'}
    return (ds * weight).mean(other_dims)

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

def fetch_nc(zstore):
    """Extract data for a single file.
    :param zstore:                str of the location of the cmip6 data file on pangeo.
    :return:                      an xarray containing cmip6 data downloaded from the pangeo.
    """
    ds = xr.open_zarr(fsspec.get_mapper(zstore))
    ds.sortby('time')
    return ds

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

# How to create Pangeo .csv - stitches method
# Get pangeo table - model, variable info + zstore address
dat = fetch_pangeo_table()
dat = pd.read_csv("pangeo_table.csv")

# Accessing data
# Returns string to Net CDF location
# Access first for testing, then all for processing
address = dat[(dat['variable']=='tas') & (dat['domain'] == 'Amon')].zstore.iloc[0]
address_all = dat[(dat['variable']=='tas') & (dat['domain'] == 'Amon')].zstore

# Get identifiers for each address
# Helpful for tagging
mod = dat['model']
exp = dat['experiment']
ens = dat['ensemble']
var = dat["variable"]
dom = dat["domain"]
names = mod + "_" + exp + "_" + ens + "_" + var + "_" + dom

# Combine identifiers with address and clean up data
tdata = pd.concat([mod, exp, ens, var, dom, address_all, names], axis = 1)
tdata = tdata.dropna()
tdata.columns = ['model', 'experiment', 'ensemble', 'variable', 'domain', 'address', 'names']
tdata = tdata.reset_index(drop = True)

# Remove runs that aren't working
# Error message: Variable 'time_bnds' has conflicting _FillValue (nan) and missing_value (1.0000000200408773e+20). Cannot encode data.
tdata = tdata[tdata["model"] != "MCM-UA-1-0"]

# Process data
for items in tdata["address"]:
    # Get from cloud
    x = fetch_nc(items)
    # Get global mean - monthly data - coarsen to annual
    globalmean = global_mean(x)
    annual_mean = globalmean.coarsen(time=12).mean()
    # Get data information
    meta = get_ds_meta(x)
    # Get date information
    t = annual_mean["time"].dt.strftime("%Y%m%d").values
    year = list(map(lambda x: selstr(x, start=0, stop=4), t))
    # Access values
    val = annual_mean["tas"].values
    # New dictionary with year and corresponding values
    d = {'year': year, 'value': val}
    # Create dataframe, combine with metadata
    df = pd.DataFrame(data=d)
    out = combine_df(meta, df)
    name = out["model"][0] + "_" + out["ensemble"][0] + "_" + out["experiment"][0]
    # Save as netcdf and csv files
    x.to_netcdf(name + ".nc")
    out.to_csv(name + ".csv", header=True, index=True)

