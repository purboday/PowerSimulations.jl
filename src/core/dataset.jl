abstract type AbstractDataset end

get_data_resolution(s::AbstractDataset)::Dates.Millisecond = s.resolution
get_last_recorded_row(s::AbstractDataset) = s.last_recorded_row

"""
Return the timestamp from the data used in the last update
"""
get_update_timestamp(s::AbstractDataset) = s.update_timestamp

function set_last_recorded_row!(s::AbstractDataset, val::Int)
    s.last_recorded_row = val
    return
end

function set_update_timestamp!(s::AbstractDataset, val::Dates.DateTime)
    s.update_timestamp = val
    return
end

# Values field is accessed with dot syntax to avoid type instability

mutable struct InMemoryDataset{N} <: AbstractDataset
    "Data with dimensions (N column names, row indexes)"
    values::DenseAxisArray{Float64, N}
    # We use Array here to allow for overwrites when updating the state
    timestamps::Vector{Dates.DateTime}
    # Resolution is needed because AbstractDataset might have just one row
    resolution::Dates.Millisecond
    end_of_step_index::Int
    last_recorded_row::Int
    update_timestamp::Dates.DateTime
end

function InMemoryDataset(
    values::DenseAxisArray{Float64, N},
    timestamps::Vector{Dates.DateTime},
    resolution::Dates.Millisecond,
    end_of_step_index::Int,
) where {N}
    return InMemoryDataset{N}(
        values,
        timestamps,
        resolution,
        end_of_step_index,
        0,
        UNSET_INI_TIME,
    )
end

function InMemoryDataset(values::DenseAxisArray{Float64, N}) where {N}
    return InMemoryDataset{N}(
        values,
        Vector{Dates.DateTime}(),
        Dates.Second(0.0),
        1,
        0,
        UNSET_INI_TIME,
    )
end

# Helper method for one dimensional cases
function InMemoryDataset(
    fill_val::Float64,
    initial_time::Dates.DateTime,
    resolution::Dates.Millisecond,
    end_of_step_index::Int,
    row_count::Int,
    column_names::Vector{String})
    return InMemoryDataset(
        fill_val,
        initial_time,
        resolution,
        end_of_step_index,
        row_count,
        (column_names,),
    )
end

function InMemoryDataset(
    fill_val::Float64,
    initial_time::Dates.DateTime,
    resolution::Dates.Millisecond,
    end_of_step_index::Int,
    row_count::Int,
    column_names::NTuple{N, <:Any}) where {N}
    return InMemoryDataset(
        fill!(
            DenseAxisArray{Float64}(undef, column_names..., 1:row_count),
            fill_val,
        ),
        collect(
            range(
                initial_time;
                step = resolution,
                length = row_count,
            ),
        ),
        resolution,
        end_of_step_index,
    )
end

get_num_rows(s::InMemoryDataset{N}) where {N} = size(s.values)[N]

function make_system_state(
    timestamp::Dates.DateTime,
    resolution::Dates.Millisecond,
    columns::NTuple{N, <:Any},
) where {N}
    return InMemoryDataset(NaN, timestamp, resolution, 0, 1, columns)
end

function get_dataset_value(s::InMemoryDataset, date::Dates.DateTime)
    s_index = find_timestamp_index(s.timestamps, date)
    if isnothing(s_index)
        error("Request time stamp $date not in the state")
    end
    return s.values[:, s_index]
end

function get_column_names(k::OptimizationContainerKey, s::InMemoryDataset)
    return get_column_names(k, s.values)
end

function get_last_recorded_value(s::InMemoryDataset)
    if get_last_recorded_row(s) == 0
        error("The Dataset hasn't been written yet")
    end
    return s.values[:, get_last_recorded_row(s)]
end

function get_end_of_step_timestamp(s::InMemoryDataset)
    return s.timestamps[s.end_of_step_index]
end

"""
Return the timestamp from most recent data row updated in the dataset. This value may not be the same as the result from `get_update_timestamp`
"""
function get_last_updated_timestamp(s::InMemoryDataset)
    last_recorded_row = get_last_recorded_row(s)
    if last_recorded_row == 0
        return UNSET_INI_TIME
    end
    return s.timestamps[last_recorded_row]
end

function get_value_timestamp(s::InMemoryDataset, date::Dates.DateTime)
    s_index = find_timestamp_index(s.timestamps, date)
    if isnothing(s_index)
        error("Request time stamp $date not in the state")
    end
    return s.timestamps[s_index]
end

function set_value!(s::InMemoryDataset, vals::DenseAxisArray{Float64, 2}, index::Int)
    s.values[:, index] = vals[:, index]
    return
end

function set_value!(s::InMemoryDataset, vals::DenseAxisArray{Float64, 1}, index::Int)
    s.values[:, index] = vals
    return
end

function set_value!(s::InMemoryDataset, vals::DenseAxisArray{Float64, 3}, index::Int)
    s.values[:, :, index] = vals
    return
end

# HDF5Dataset does not account of overwrites in the data. Values are written sequentially.
mutable struct HDF5Dataset <: AbstractDataset
    values::HDF5.Dataset
    column_dataset::HDF5.Dataset
    write_index::Int
    last_recorded_row::Int
    resolution::Dates.Millisecond
    initial_timestamp::Dates.DateTime
    update_timestamp::Dates.DateTime
    column_names::Vector{String}

    function HDF5Dataset(values, column_dataset, write_index, last_recorded_row, resolution,
        initial_timestamp,
        update_timestamp, column_names,
    )
        new(values, column_dataset, write_index, last_recorded_row, resolution,
            initial_timestamp,
            update_timestamp, column_names)
    end
end

HDF5Dataset(values, column_dataset, resolution, initial_time) =
    HDF5Dataset(
        values,
        column_dataset,
        1,
        0,
        resolution,
        initial_time,
        UNSET_INI_TIME,
        column_dataset[:],
    )

function _make_column_names(vals::Vector{String})
    return (vals,)
end

function _make_column_names(vals::Matrix{String})
    return (vals[:, 1], vals[:, 2])
end

function get_column_names(::OptimizationContainerKey, s::HDF5Dataset)
    return _make_column_names(s.column_names)
end

"""
Return the timestamp from most recent data row updated in the dataset. This value may not be the same as the result from `get_update_timestamp`
"""
function get_last_updated_timestamp(s::HDF5Dataset)
    last_recorded_row = get_last_recorded_row(s)
    if last_recorded_row == 0
        return UNSET_INI_TIME
    end
    return s.initial_timestamp + s.resolution * (last_recorded_row - 1)
end

function get_value_timestamp(s::HDF5Dataset, date::Dates.DateTime)
    error("Not implemented for HDF5Dataset. Required if it is used for simulation state.")
    # TODO: This code is broken because timestamps is not a field.
    #s_index = find_timestamp_index(s.timestamps, date)
    #if isnothing(s_index)
    #    error("Request time stamp $date not in the state")
    #end
    #return s.initial_timestamp + s.resolution * (s_index - 1)
end

function set_value!(s::HDF5Dataset, vals, index::Int)
    # Temporary while there is no implementation of caching of em_data
    _write_dataset!(s.values, vals, index:index)
    return
end
