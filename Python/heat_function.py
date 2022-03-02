def mean_heatflux(path):
    """ For a pangeo file, calculate the area weighted ocean mean. To be used with heat flux variables.

    :param path:  str zstore path corresponding to a pangeo netcdf

    :return:      pandas.core.frame.DataFrame of area-weighted HL tos from a single netcdf file
    """
    ds = xr.open_zarr(fsspec.get_mapper(path), consolidated=True)

    # Extract the meta data
    meta_data = get_ds_meta(ds)

    # Based on the meta data find the correct areacella file
    df = pd.read_csv('https://storage.googleapis.com/cmip6/cmip6-zarr-consolidated-stores.csv')
    query1 = "variable_id == 'areacella' & source_id == '" + meta_data.model[0] + "'"
    query2 = "variable_id == 'sftlf' & source_id == '" + meta_data.model[0] + "'"
    df_area = df.query(query1)
    if df_area.shape[0] < 1:
        raise RuntimeError("Could not find areacella for " + path)
    df_landper = df.query(query2)
    if df_landper.shape[0] < 1:
        raise RuntimeError("Could not find sftlf for " + path)

    # Read in the area cella file
    ds_area = xr.open_zarr(fsspec.get_mapper(df_area.zstore.values[0]), consolidated=True)
    ds_landper = xr.open_zarr(fsspec.get_mapper(df_landper.zstore.values[0]), consolidated=True)

    # Select only the ocean cell area values in the HL regions, use this mask as the area weights.
    ### CHANGE THIS
    # (1 * mask) replaces T/F with 0 and 1
    mask = 1 * (ds_area['areacella'] * (1 - (0.01 * ds_landper['sftlf'])))
    # Replace 0 and 1 with NA
    mask = xr.where(mask == 0, np.nan, mask)
    masked_area = ds_area * mask

    # Using the ocean cell area and total area calculate the weighted mean over the ocean.
    total_area = masked_area.areacella.sum(set(masked_area.areacella.dims), skipna=True)
    other_dims = set(ds.rsds.dims) - {'time'}

    # Weighted average calculation
    wa = (ds.rsds * masked_area.areacella).sum(dim=other_dims) / total_area
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
    # Save as netcdf and csv files
    # x.to_netcdf(name + ".nc")
    out.to_csv(name + ".csv", header=True, index=True)

#  x9, A x8,  x2,
# NorESM2-LM, FGOALS-g3 x3, KACE-1-0-G x 2,
# EC-Earth3-Veg x1,
skip = [# BCC-ESM1
        36, 37, 44, 45, 90, 91, 92, 93, 158,
        # AWI-CM-1-1-MR
        480, 481, 482, 483, 485, 486, 487, 488, 687, 688,
        # NUIST/NESM3
        528, 529, 608, 609, 610, 611, 612, 613,
        # NorESM2-LM
        625, 697, 698, 699, 704, 710, 713, 714, 716,
        # FGOALS-g3
        627, 628, 629, 683, 684, 685, 686, 689, 690, 691, 756, 757, 758, 759, 760, 761, 762-768, 770, 771, 773,
        891, 915, 916, 917, 1019,
        # KACE-1-0-G
        655, 656, 659, 677, 678, 679, 680, 681, 745, 746, 747, 748, 749, 750,
        # EC-Earth3-Veg / EC-Earth3-CC
        666, 668, 859, 868, 874, 875, 876, 877, 880, 1044
        # GISS-E2-2-G
        720, 721,
        # CCCR-IITM
        753, 772,
        # INM-CM5-0
        863,
        #CSIRO-ARCCSS/ACCESS-CM2
        864, 865, 885, 886
        # AS-RCEC
        866,
        # CAS-ESM2-0
        869, 873,
        # THU/CIESM
        881, 882, 883, 884, 909,
        # FIO-ESM-2-0
        1007, 1008, 1009, 1013, 1014, 1015, 1015, 1017, 1018, 1020, 1021, 1022, 1023, 1024, 1025,
        # CCCR-IITM
        1010, 1011, 1012]

for items in address_rsds[1045:1047]:
    mean_heatflux(items)