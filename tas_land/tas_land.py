# Processing CMIP6 surface temperature over land data using Pangeo
# February 2022
# Leeya Pressburger

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

    :param path:  str zstore path corresponding to a pangeo netcdf

    :return:      pandas.core.frame.DataFrame of area-weighted land tas from a single netcdf file
    """
    ds = xr.open_zarr(fsspec.get_mapper(path), consolidated=True)
    df = pd.read_csv('https://storage.googleapis.com/cmip6/cmip6-zarr-consolidated-stores.csv')

    # Extract the meta data
    meta_data = get_ds_meta(ds)

    # Based on the meta data find the correct areacella file
    query1 = "variable_id == 'areacella' & source_id == '" + meta_data.model[0] + "'"
    query2 = "variable_id == 'sftlf' & source_id == '" + meta_data.model[0] + "'"

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

    name = out["model"][0] + "_" + out["ensemble"][0] + "_" + out["experiment"][0] + "_" + out["frequency"][0]
    # Save as csv
    out.to_csv(name + ".csv", header=True, index=True)

# Access Pangeo files
dat = fetch_pangeo_table()

# Pull out specifics
exps = ['1pctCO2', 'abrupt-4xCO2', 'abrupt-2xCO2', 'esm-hist', 'esm-ssp585', 'ssp119',
        'ssp126', 'ssp245', 'ssp370', 'ssp434', 'ssp460', 'ssp585']

mips = ['CMIP', 'ScenarioMIP']

# Access desired zstore addresses
address_all = dat[(dat['variable_id'] == 'tas') & (dat['experiment_id'].isin(exps)) &
                   (dat['table_id'] == 'Amon') & (dat['activity_id'].isin(mips))].zstore

address_all = address_all.reset_index(drop=True)

# Loop
for items in address_all[1857:1887]:
    get_land_tas(items)


# Note failing models and (most) locations
skips = [# BCC-CSM2-MR
        35, 36, 42, 43, 44, 85, 86, 87, 88,
        # AWI-CM-1-1-MR
        471, 472, 473, 474, 475, 476, 477, 478, 479, 688, 689,
        # NUIST/NESM3
         514, 515, 600, 601, 604, 608, 610, 611,
        # MCM-UA-1-0
        602, 603, 605, 606, 607, 609,
        #NorESM2-LM
        628, 699, 700, 701, 705, 710, 713, 714, 715,
        940,
        # FGOALS-g3
        629, 630, 631, 756, 757, 758, 759, 760, 761, 762,
        763, 764, 765, 766, 767, 775, 776, 787,
        1161, 1338, 1347, 1348, 1349,
        #FGOALS-f3-L
        684, 685, 686, 687, 690, 691, 692,
        1193, 1194, 1195,
        # KACE-1-0-G
        658, 659, 662, 678, 679, 680, 681, 682,
        768, 769, 770, 771, 772, 773,
        # GISS-E2-2-G
        721, 722, 723,
        # IITM-ESM
        751, 777,
        # FIO-ESM-2-0
        778, 779, 780, 781, 782, 783, 784, 785, 786,
        956, 957, 958, 959, 960, 961,
        # THU/CIESM
        1186,
        # CCCR-IITM
        1335, 1336, 1337, 1386,
        # EC-Earth3-Veg-LR
        1409,
        # EC-Earth3
        1412, 1413, 1417,
        # IPSL-CM5A2-INCA
        1414, 1415, 1416
        # ICON-ESM-LR
        # KIOST-ESM]

1484 - 1546