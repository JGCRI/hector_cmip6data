# Area weighted mean tos for low latitudes (LL) where latitude < |55|
# 0. Load packages
import fsspec
import intake  # must be v 0.6.2
import xarray as xr
import os as os
import pandas as pd
import numpy as np


# 1. Define functions
def get_ds_meta(ds):
    """ Get the meta data information from the xarray data set.

    :param ds:  xarray dataset of CMIP data.

    :return:    pandas dataset of MIP information.
    """
    v = ds.variable_id

    data = [{'variable': v,
             'experiment': ds.experiment_id,
             'units': ds[v].attrs['units'],
             'ensemble': ds.attrs["variant_label"],
             'model': ds.source_id}]
    df = pd.DataFrame(data)

    return df


def get_lat_name(ds):
    """ Get the name for the latitude values (could be either lat or latitude).

    :param ds:    xarray dataset of CMIP data.

    :return:    the string name for the latitude variable.
    """
    for lat_name in ['lat', 'latitude']:
        if lat_name in ds.coords:
            return lat_name
    raise RuntimeError("Couldn't find a latitude coordinate")


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


def mean_LL_tos(path):
    """ For a pangeo tos file calculate the area weighted mean tos for the HL region.

    :param path:  str zstore path corresponding to a pangeo netcdf

    :return:      pandas.core.frame.DataFrame of area-weighted HL tos from a single netcdf file
    """
    ds = xr.open_zarr(fsspec.get_mapper(path), consolidated=True)

    # Extract the meta data & the latitude name.
    meta_data = get_ds_meta(ds)
    lat_name = get_lat_name(ds)

    # Based on the meta data find the correct areacello file
    df = pd.read_csv('https://storage.googleapis.com/cmip6/cmip6-zarr-consolidated-stores.csv')
    query = "variable_id == 'areacello' & source_id == '" + meta_data.model[0] + "'" + \
            " & grid_label == 'gn' & experiment_id == '" + meta_data.experiment[0] + \
            "' & member_id == '" + meta_data.ensemble[0] + "'"
    df_area = df.query(query)
    if df_area.shape[0] < 1:
        raise RuntimeError("Could not find areacello for " + path)

    # Read in the area cello file
    ds_area = xr.open_zarr(fsspec.get_mapper(df_area.zstore.values[0]), consolidated=True)

    # Select only the ocean cell area values in the HL regions, use this mask as the area weights.
    mask = 1 * (ds_area[lat_name] <= 55) & (ds_area[lat_name] >= -55)
    mask = xr.where(mask == 0, np.nan, mask)
    masked_area = ds_area * mask

    # Using the ocean cell area and total area calculate the weighted mean over the ocean.
    total_area = masked_area.areacello.sum(set(masked_area.areacello.dims), skipna=True)
    other_dims = set(ds.tos.dims) - {'time'}
    tos_ts = (ds.tos * masked_area.areacello).sum(dim=other_dims) / total_area
    tos_ts = tos_ts.coarsen(time=12).mean()

    # Extract time information.
    t = tos_ts["time"].dt.strftime("%Y%m%d").values
    year = list(map(lambda x: selstr(x, start=0, stop=4), t))

    # Format into a data frame.
    val = tos_ts.values
    d = {'year': year, 'value': val}
    df = pd.DataFrame(data=d)
    out = combine_df(meta_data, df)
    out["area"] = "LL"

    return (out)


# 2. Process area-weighted tos for the HL region.

## The url path that contains to the pangeo archive table of contents.
url = "https://storage.googleapis.com/cmip6/pangeo-cmip6.json"
catalog = intake.open_esm_datastore(url)

# Set the parameters of our search, we need the tos and the ocean cell area.
expts = ['historical']
cmip_vars = ["tos"]
query = dict(
    experiment_id=expts,
    variable_id=cmip_vars,
    grid_label="gn",
    table_id = "Omon"
)

# Process the files -------------------------------------------------------------------------
catalog = catalog.search(require_all_on=["source_id"], **query)
catalog = catalog.df.copy().reset_index(drop=True)
catalog = catalog.loc[catalog['member_id'].str.contains('p1')].copy().reset_index(drop=True)

# Set up the output directory and process the files.
outdir = './LL/'
if not os.path.exists(outdir):
    os.mkdir(outdir)

# Process the files
for file in catalog["zstore"]:
    print(file)
    try:
        ofile = outdir + file.replace("/", "_") + '.csv'
        out = mean_LL_tos(file)
        out.to_csv(ofile, index=False)
    except:
        print("problem with " + file)




