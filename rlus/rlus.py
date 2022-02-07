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
    other_dims = set(ds.rlus.dims) - {'time'}

    # Weighted average calculation
    wa = (ds.rlus * masked_area.areacella).sum(dim=other_dims) / total_area
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

address_rlus = pd.read_csv("rlus_addresses.csv")
address_rlus= address_rlus["x"]

address_skips = address_rlus.drop(skips)
address_skips = address_skips.drop(483)
address_skips2 = address_skips1.drop(nums)

for items in address_rlus[1045:1047]:
    mean_heatflux(items)

nums = [678, 679, 680, 681, 682, 684, 685, 686, 687, 688, 689, 690, 691, 692, 698, 699, 700, 721, 722, 746, 747, 748, 749, 750, 751,
        757, 758, 759, 760, 761, 762, 763, 764, 765, 766, 767, 768, 769, 771, 772, 774]

skips = [
        # FGOALS-g3
        908, 909, 910, 1018,
        # CCCR-IITM
        753, 1010, 1011, 1012,
        # EC-Earth3, EC-Earth3-Veg - not enough values to unpack
        859, 868, 872, 873, 874, 876, 878, 1039, 1044,
        # THU/CIESM
        997, 998, 999, 1000, 1001,
        # CAS-ESM2-0
        1005, 1006,
        # FIO-ESM-2-0
        1007, 1008, 1009, 1013, 1014, 1015, 1016, 1017,
        1019, 1020, 1021, 1022, 1023, 1024, 1025]