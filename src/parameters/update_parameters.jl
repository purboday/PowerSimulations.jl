function update_parameter_values!(
    ::AbstractArray{T},
    ::NoAttributes,
    args...,
) where {T <: Union{Float64, PJ.ParameterRef}} end

######################## Methods to update Parameters from Time Series #####################
function _set_param_value!(
    param::AbstractArray{PJ.ParameterRef},
    value::Float64,
    name::String,
    t::Int,
)
    JuMP.set_value(param[name, t], value)
    return
end

function _set_param_value!(
    param::AbstractArray{Float64},
    value::Float64,
    name::String,
    t::Int,
)
    param[name, t] = value
    return
end

function update_parameter_values!(
    param_array::AbstractArray{T},
    attributes::TimeSeriesAttributes{U},
    ::Type{V},
    model::DecisionModel,
    state,
) where {
    T <: Union{PJ.ParameterRef, Float64},
    U <: PSY.AbstractDeterministic,
    V <: PSY.Device,
}
    initial_forecast_time = get_current_time(model) # Function not well defined for DecisionModels
    horizon = get_time_steps(get_optimization_container(model))[end]
    components = get_available_components(V, get_system(model))
    for component in components
        ts_vector = get_time_series_values!(
            U,
            model,
            component,
            get_name(attributes),
            initial_forecast_time,
            horizon,
        )
        name = PSY.get_name(component)
        for (t, value) in enumerate(ts_vector)
            _set_param_value!(param_array, value, name, t)
        end
    end
end

function update_parameter_values!(
    param_array::AbstractArray{T},
    attributes::TimeSeriesAttributes{U},
    ::Type{V},
    model::EmulationModel,
    state,
) where {T <: Union{PJ.ParameterRef, Float64}, U <: PSY.SingleTimeSeries, V <: PSY.Device}
    initial_forecast_time = get_current_time(model)
    components = get_available_components(V, get_system(model))
    for component in components
        # Note: This interface reads one single value per component at a time.
        ts_vector = get_time_series_values!(
            U,
            model,
            component,
            get_name(attributes),
            initial_forecast_time,
        )
        _set_param_value!(param_array, ts_vector[1], PSY.get_name(component), 1)
    end
    return
end

function update_parameter_values!(
    param_array::AbstractArray{T},
    attributes::VariableValueAttributes,
    ::Type{<:PSY.Component},
    model::DecisionModel,
    state,
) where {T <: Union{PJ.ParameterRef, Float64}}
    current_time = get_current_time(model)
    state_data = get_decision_state_data(state, get_attribute_key(attributes))
    state_values = get_state_values(state_data)
    component_names, time = axes(param_array)
    resolution = get_resolution(model)
    # TODO: check if this is the most performant way to find the common indices
    state_timestamps = get_timestamps(state_data)
    max_state_index = length(state_timestamps)
    state_data_index = findlast(state_timestamps .<= current_time)
    sim_timestamps = range(current_time, step = resolution, length = time[end])
    for name in component_names, t in time
        time_stamp_ix = min(max_state_index, state_data_index + 1)
        @debug "parameter horizon is over the step" max_state_index > state_data_index + 1
        if state_timestamps[time_stamp_ix] < sim_timestamps[t]
            state_data_index = time_stamp_ix
        end
        # Pass indices in this way since JuMP DenseAxisArray don't support view()
        _set_param_value!(param_array, state_values[state_data_index, name], name, t)
    end
    return
end

"""
Update parameter function an OperationModel
"""
function update_parameter_values!(
    model::OperationModel,
    ::ParameterKey{T, U},
    input::Any,
) where {T <: ParameterType, U <: PSY.Device}
    TimerOutputs.@timeit RUN_SIMULATION_TIMER "$T $U Parameter Update" begin
        optimization_container = get_optimization_container(model)
        parameter_array = get_parameter_array(optimization_container, T(), U)
        parameter_attributes = get_parameter_attributes(optimization_container, T(), U)
        update_parameter_values!(parameter_array, parameter_attributes, U, model, input)
        IS.@record :execution ParameterUpdateEvent(
            T,
            U,
            parameter_attributes,
            get_current_timestamp(model),
            get_name(model),
        )
    end
    return
end
