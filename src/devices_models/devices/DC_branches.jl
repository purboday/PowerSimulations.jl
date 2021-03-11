abstract type AbstractDCLineFormulation <: AbstractBranchFormulation end
struct HVDCUnbounded <: AbstractDCLineFormulation end
struct HVDCLossless <: AbstractDCLineFormulation end
struct HVDCDispatch <: AbstractDCLineFormulation end
# Not Implemented
# struct VoltageSourceDC <: AbstractDCLineFormulation end

#################################### Branch Variables ##################################################
get_variable_binary(_, ::Type{<:PSY.DCBranch}, ::AbstractDCLineFormulation) = false

get_variable_sign(::FlowActivePowerVariable, ::Type{<:PSY.DCBranch}, _) = NaN

get_variable_sign(::FlowActivePowerFromToVariable, ::Type{<:PSY.DCBranch}, ::AbstractDCLineFormulation) = -1.0
get_variable_sign(::FlowActivePowerToFromVariable, ::Type{<:PSY.DCBranch}, ::AbstractDCLineFormulation) = 1.0

get_variable_lower_bound(::FlowActivePowerVariable, d::PSY.DCBranch, ::HVDCLossless) = max(PSY.get_active_power_limits_from(d).min, PSY.get_active_power_limits_to(d).min)
get_variable_upper_bound(::FlowActivePowerVariable, d::PSY.DCBranch, ::HVDCLossless) = min(PSY.get_active_power_limits_from(d).max, PSY.get_active_power_limits_to(d).max)

get_variable_lower_bound(::FlowActivePowerFromToVariable, d::PSY.DCBranch, ::AbstractThermalFormulation) = PSY.get_active_power_limits_from(d).min
get_variable_upper_bound(::FlowActivePowerFromToVariable, d::PSY.DCBranch, ::AbstractThermalFormulation) = PSY.get_active_power_limits_from(d).max

get_variable_lower_bound(::FlowActivePowerToFromVariable, d::PSY.DCBranch, ::AbstractThermalFormulation) = PSY.get_active_power_limits_to(d).min
get_variable_upper_bound(::FlowActivePowerToFromVariable, d::PSY.DCBranch, ::AbstractThermalFormulation) = PSY.get_active_power_limits_to(d).max

get_variable_lower_bound(::FlowActivePowerFromToVariable, d::PSY.DCBranch, ::HVDCUnbounded) = nothing
get_variable_upper_bound(::FlowActivePowerFromToVariable, d::PSY.DCBranch, ::HVDCUnbounded) = nothing

get_variable_lower_bound(::FlowActivePowerToFromVariable, d::PSY.DCBranch, ::HVDCUnbounded) = nothing
get_variable_upper_bound(::FlowActivePowerToFromVariable, d::PSY.DCBranch, ::HVDCUnbounded) = nothing

#! format: on

#################################### Flow Variable Bounds ##################################################
function add_variable_to_expression!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, HVDCLossless},
    ::Type{S},
    ) where {B <: PSY.DCBranch, S <: Union{StandardPTDFModel, PTDFPowerModel}}
    time_steps = model_time_steps(optimization_container)
    var = get_variable(optimization_container, FLOW_ACTIVE_POWER, B)

    for (ix, d) in enumerate(devices)
        bus_fr = PSY.get_number(PSY.get_arc(d).from)
        bus_to = PSY.get_number(PSY.get_arc(d).to)
        for t in time_steps
            var[PSY.get_name(d), t] = jvariable
            add_to_expression!(
                optimization_container.expressions[:nodal_balance_active],
                PSY.get_number(PSY.get_arc(d).from),
                t,
                jvariable,
                -1.0,
            )
            add_to_expression!(
                optimization_container.expressions[:nodal_balance_active],
                PSY.get_number(PSY.get_arc(d).to),
                t,
                jvariable,
                1.0,
            )
        end
    end
end

#################################### Rate Limits Constraints ##################################################
function branch_rate_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, HVDCLossless},
    ::Type{<:PM.AbstractDCPModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {B <: PSY.DCBranch}
    var = get_variable(optimization_container, FLOW_ACTIVE_POWER, B)
    time_steps = model_time_steps(optimization_container)
    constraint_val =
        JuMPConstraintArray(undef, [PSY.get_name(d) for d in devices], time_steps)
    assign_constraint!(optimization_container, FLOW_ACTIVE_POWER, B, constraint_val)
    for t in time_steps, d in devices
        min_rate = max(
            PSY.get_active_power_limits_from(d).min,
            PSY.get_active_power_limits_to(d).min,
        )
        max_rate = min(
            PSY.get_active_power_limits_from(d).max,
            PSY.get_active_power_limits_to(d).max,
        )
        constraint_val[PSY.get_name(d), t] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            min_rate <= var[PSY.get_name(d), t] <= max_rate
        )
    end
    return
end

branch_rate_constraints!(
    ::OptimizationContainer,
    ::IS.FlattenIteratorWrapper{<:PSY.DCBranch},
    ::DeviceModel{<:PSY.DCBranch, HVDCUnbounded},
    ::Type{<:PM.AbstractPowerModel},
    ::Union{Nothing, AbstractAffectFeedForward},
) = nothing

#=
function branch_rate_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, HVDCLossless},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {B <: PSY.DCBranch}
    for (var_type, cons_type) in zip(
        (FLOW_ACTIVE_POWER_FROM_TO, FLOW_ACTIVE_POWER_TO_FROM),
        (RATE_LIMIT_FT, RATE_LIMIT_TF),
    )
        var = get_variable(optimization_container, var_type, B)
        time_steps = model_time_steps(optimization_container)
        constraint_val =
            JuMPConstraintArray(undef, [PSY.get_name(d) for d in devices], time_steps)
        assign_constraint!(optimization_container, cons_type, B, constraint_val)
        time_steps = model_time_steps(optimization_container)

        for t in time_steps, d in devices
            min_rate = max(
                PSY.get_active_power_limits_from(d).min,
                PSY.get_active_power_limits_to(d).min,
            )
            max_rate = min(
                PSY.get_active_power_limits_from(d).max,
                PSY.get_active_power_limits_to(d).max,
            )
            name = PSY.get_name(d)
            constraint_val[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                min_rate <= var[name, t] <= max_rate
            )
        end
    end
    return
end
=#
function branch_rate_constraints!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{B},
    ::DeviceModel{B, HVDCDispatch},
    ::Type{<:PM.AbstractPowerModel},
    feedforward::Union{Nothing, AbstractAffectFeedForward},
) where {B <: PSY.DCBranch}
    time_steps = model_time_steps(optimization_container)
    for (var_type, cons_type) in zip(
        (FLOW_ACTIVE_POWER_FROM_TO, FLOW_ACTIVE_POWER_TO_FROM),
        (RATE_LIMIT_FT, RATE_LIMIT_TF),
    )
        var = get_variable(optimization_container, var_type, B)
        constraint_val =
            JuMPConstraintArray(undef, [PSY.get_name(d) for d in devices], time_steps)
        assign_constraint!(optimization_container, cons_type, B, constraint_val)

        for t in time_steps, d in devices
            min_rate = max(
                PSY.get_active_power_limits_from(d).min,
                PSY.get_active_power_limits_to(d).min,
            )
            max_rate = min(
                PSY.get_active_power_limits_from(d).max,
                PSY.get_active_power_limits_to(d).max,
            )
            constraint_val[PSY.get_name(d), t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                min_rate <= var[PSY.get_name(d), t] <= max_rate
            )
            add_to_expression!(
                optimization_container.expressions[:nodal_balance_active],
                PSY.get_number(PSY.get_arc(d).to),
                t,
                var[PSY.get_name(d), t],
                -PSY.get_loss(d).l1,
                -PSY.get_loss(d).l0,
            )
        end
    end
    return
end
