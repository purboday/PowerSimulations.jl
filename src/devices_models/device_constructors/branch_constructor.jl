################################# Generic AC Branch  Models ################################
# These 3 methods are defined on concrete formulations of the branches to avoid ambiguity
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, StaticBranch},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    devices = get_available_components(model, sys)
    if has_subnetworks(network_model)
        if get_use_slacks(model)
            add_variables!(
                container,
                FlowActivePowerSlackUpperBound,
                network_model,
                devices,
                StaticBranch(),
            )
            add_variables!(
                container,
                FlowActivePowerSlackLowerBound,
                network_model,
                devices,
                StaticBranch(),
            )
        end

        add_variables!(
            container,
            FlowActivePowerVariable,
            network_model,
            devices,
            StaticBranch(),
        )
        add_to_expression!(
            container,
            ActivePowerBalance,
            FlowActivePowerVariable,
            devices,
            model,
            network_model,
        )
    end
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranch},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    devices = get_available_components(model, sys)
    if has_subnetworks(network_model)
        devices =
            get_available_components(model, sys)
        add_constraints!(
            container,
            RateLimitConstraint,
            devices,
            model,
            network_model,
        )
        add_constraint_dual!(container, sys, model)
    end
    add_feedforward_constraints!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, StaticBranchBounds},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    if get_use_slacks(model)
        throw(ArgumentError("StaticBranchBounds is not compatible with the use of slacks"))
    end
    devices = get_available_components(model, sys)
    if has_subnetworks(network_model)
        add_variables!(
            container,
            FlowActivePowerVariable,
            network_model,
            devices,
            StaticBranchBounds(),
        )
        add_to_expression!(
            container,
            ActivePowerBalance,
            FlowActivePowerVariable,
            devices,
            model,
            network_model,
        )
    end
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranchBounds},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    devices = get_available_components(model, sys)
    if has_subnetworks(network_model)
        branch_rate_bounds!(
            container,
            devices,
            model,
            network_model,
        )
    end
    add_feedforward_constraints!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, StaticBranchUnbounded},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
) where {T <: PSY.ACBranch}
    devices = get_available_components(model, sys)
    if has_subnetworks(network_model)
        add_variables!(
            container,
            FlowActivePowerVariable,
            network_model,
            devices,
            StaticBranchUnbounded(),
        )
        add_to_expression!(
            container,
            ActivePowerBalance,
            FlowActivePowerVariable,
            devices,
            model,
            network_model,
        )
    end
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    network_model::Union{
        NetworkModel{CopperPlatePowerModel},
        NetworkModel{AreaBalancePowerModel},
    },
)
    devices = get_available_components(model, sys)
    add_feedforward_constraints!(container, model, devices)
    return
end

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    ::NetworkModel{<:PM.AbstractPowerModel},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    ::NetworkModel{<:PM.AbstractPowerModel},
) = nothing

# For DC Power only. Implements constraints
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    device_model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(device_model, sys)
    if get_use_slacks(device_model)
        add_variables!(
            container,
            FlowActivePowerSlackUpperBound,
            devices,
            StaticBranch(),
        )
        add_variables!(
            container,
            FlowActivePowerSlackLowerBound,
            devices,
            StaticBranch(),
        )
    end
    add_feedforward_arguments!(container, device_model, devices)
    return
end

# For DC Power only. Implements constraints
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    device_model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{U},
) where {T <: PSY.ACBranch, U <: PM.AbstractActivePowerModel}
    @debug "construct_device" _group = LOG_GROUP_BRANCH_CONSTRUCTIONS

    devices = get_available_components(device_model, sys)
    add_constraints!(container, RateLimitConstraint, devices, device_model, network_model)
    add_feedforward_constraints!(container, device_model, devices)
    objective_function!(container, devices, device_model, U)
    add_constraint_dual!(container, sys, device_model)
    return
end

# For DC Power only
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(model, sys)
    if get_use_slacks(model)
        add_variables!(
            container,
            FlowActivePowerSlackUpperBound,
            network_model,
            devices,
            StaticBranch(),
        )
        add_variables!(
            container,
            FlowActivePowerSlackLowerBound,
            network_model,
            devices,
            StaticBranch(),
        )
    end

    add_variables!(
        container,
        FlowActivePowerVariable,
        network_model,
        devices,
        StaticBranch(),
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(model, sys)
    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    add_constraints!(container, RateLimitConstraint, devices, model, network_model)
    add_feedforward_constraints!(container, model, devices)
    objective_function!(container, devices, model, PTDFPowerModel)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, StaticBranchBounds},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(model, sys)

    if get_use_slacks(model)
        throw(ArgumentError("StaticBranchBounds is not compatible with the use of slacks"))
    end

    add_variables!(
        container,
        FlowActivePowerVariable,
        network_model,
        devices,
        StaticBranchBounds(),
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranchBounds},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(model, sys)
    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    branch_rate_bounds!(
        container,
        devices,
        model,
        network_model,
    )
    add_feedforward_constraints!(container, model, devices)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, StaticBranchUnbounded},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(model, sys)
    add_variables!(
        container,
        FlowActivePowerVariable,
        network_model,
        devices,
        StaticBranchUnbounded(),
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranchUnbounded},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(model, sys)
    add_feedforward_constraints!(container, model, devices)
    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

# For AC Power only. Implements Bounds on the active power and rating constraints on the aparent power
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    device_model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(device_model, sys)

    if get_use_slacks(device_model)
        # Only one slack is needed for this formulations in AC
        add_variables!(
            container,
            FlowActivePowerSlackUpperBound,
            devices,
            StaticBranch(),
        )
    end
    add_feedforward_arguments!(container, device_model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, StaticBranch},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(model, sys)
    branch_rate_bounds!(container, devices, model, network_model)
    add_feedforward_constraints!(container, model, devices)
    add_constraints!(container, RateLimitConstraintFromTo, devices, model, network_model)
    add_constraints!(container, RateLimitConstraintToFrom, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    device_model::DeviceModel{T, StaticBranchBounds},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: PSY.ACBranch}
    if get_use_slacks(device_model)
        throw(
            ArgumentError(
                "StaticBranchBounds is not compatible with the use of slacks",
            ),
        )
    end
    devices = get_available_components(device_model, sys)
    add_feedforward_arguments!(container, device_model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    device_model::DeviceModel{T, StaticBranchBounds},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(device_model, sys)
    branch_rate_bounds!(container, devices, device_model, network_model)
    add_constraints!(
        container,
        RateLimitConstraintFromTo,
        devices,
        device_model,
        network_model,
    )
    add_constraints!(
        container,
        RateLimitConstraintToFrom,
        devices,
        device_model,
        network_model,
    )
    add_constraint_dual!(container, sys, device_model)
    add_feedforward_constraints!(container, device_model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    device_model::DeviceModel{T, StaticBranchBounds},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: PSY.ACBranch}
    devices = get_available_components(device_model, sys)
    branch_rate_bounds!(container, devices, device_model, network_model)
    add_constraint_dual!(container, sys, device_model)
    add_feedforward_constraints!(container, device_model, devices)
    return
end

################################### TwoTerminal HVDC Line Models ###################################
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalLossless},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {T <: TwoTerminalHVDCTypes}
    if has_subnetworks(network_model)
        devices = get_available_components(model, sys)
        add_variables!(
            container,
            FlowActivePowerVariable,
            network_model,
            devices,
            HVDCTwoTerminalLossless(),
        )
        add_to_expression!(
            container,
            ActivePowerBalance,
            FlowActivePowerVariable,
            devices,
            model,
            network_model,
        )
        add_feedforward_arguments!(container, model, devices)
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalLossless},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {T <: TwoTerminalHVDCTypes}
    if has_subnetworks(network_model)
        devices =
            get_available_components(model, sys)
        add_constraints!(
            container,
            FlowRateConstraint,
            devices,
            model,
            network_model,
        )
        add_constraint_dual!(container, sys, model)
        add_feedforward_constraints!(container, model, devices)
    end
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    device_model::DeviceModel{T, HVDCTwoTerminalUnbounded},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices = get_available_components(device_model, sys)
    add_feedforward_arguments!(container, device_model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    device_model::DeviceModel{<:TwoTerminalHVDCTypes, HVDCTwoTerminalUnbounded},
    ::NetworkModel{<:PM.AbstractPowerModel},
)
    devices = get_available_components(device_model, sys)
    add_constraint_dual!(container, sys, device_model)
    add_feedforward_constraints!(container, device_model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalUnbounded},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices = get_available_components(model, sys)
    add_variables!(container, FlowActivePowerVariable, devices, HVDCTwoTerminalUnbounded())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    device_model::DeviceModel{<:TwoTerminalHVDCTypes, HVDCTwoTerminalUnbounded},
    ::NetworkModel{CopperPlatePowerModel},
)
    devices = get_available_components(device_model, sys)
    add_constraint_dual!(container, sys, device_model)
    add_feedforward_constraints!(container, model, devices)
    return
end

# Repeated method to avoid ambiguity between HVDCTwoTerminalUnbounded and HVDCTwoTerminalLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalUnbounded},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {T <: TwoTerminalHVDCTypes}
    devices = get_available_components(model, sys)
    add_variables!(container, FlowActivePowerVariable, devices, HVDCTwoTerminalUnbounded())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

# Repeated method to avoid ambiguity between HVDCTwoTerminalUnbounded and HVDCTwoTerminalLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{<:TwoTerminalHVDCTypes, HVDCTwoTerminalUnbounded},
    network_model::NetworkModel{<:AbstractPTDFModel},
)
    devices = get_available_components(model, sys)
    add_constraint_dual!(container, sys, model)
    add_feedforward_constraints!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalLossless},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices = get_available_components(model, sys)
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalLossless},
    network_model::NetworkModel{<:PM.AbstractPowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices = get_available_components(model, sys)
    add_constraints!(container, FlowRateConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    add_feedforward_constraints!(container, model, devices)
    return
end

# Repeated method to avoid ambiguity between HVDCTwoTerminalUnbounded and HVDCTwoTerminalLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalLossless},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {T <: TwoTerminalHVDCTypes}
    devices = get_available_components(model, sys)
    add_variables!(container, FlowActivePowerVariable, devices, HVDCTwoTerminalLossless())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

# Repeated method to avoid ambiguity between HVDCTwoTerminalUnbounded and HVDCTwoTerminalLossless
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalLossless},
    network_model::NetworkModel{PTDFPowerModel},
) where {
    T <: TwoTerminalHVDCTypes,
}
    devices = get_available_components(model, sys)
    add_constraints!(container, FlowRateConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    add_feedforward_constraints!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalDispatch},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {T <: TwoTerminalHVDCTypes}
    devices = get_available_components(model, sys)
    add_variables!(
        container,
        FlowActivePowerToFromVariable,
        devices,
        HVDCTwoTerminalDispatch(),
    )
    add_variables!(
        container,
        FlowActivePowerFromToVariable,
        devices,
        HVDCTwoTerminalDispatch(),
    )
    add_variables!(container, HVDCLosses, devices, HVDCTwoTerminalDispatch())
    add_variables!(container, HVDCFlowDirectionVariable, devices, HVDCTwoTerminalDispatch())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerToFromVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerFromToVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        HVDCLosses,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalDispatch},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {T <: TwoTerminalHVDCTypes}
    devices = get_available_components(model, sys)
    add_constraints!(container, FlowRateConstraintFromTo, devices, model, network_model)
    add_constraints!(container, FlowRateConstraintToFrom, devices, model, network_model)
    add_constraints!(container, HVDCPowerBalance, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    add_feedforward_constraints!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalDispatch},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices = get_available_components(model, sys)
    add_variables!(
        container,
        FlowActivePowerToFromVariable,
        devices,
        HVDCTwoTerminalDispatch(),
    )
    add_variables!(
        container,
        FlowActivePowerFromToVariable,
        devices,
        HVDCTwoTerminalDispatch(),
    )
    add_variables!(container, HVDCFlowDirectionVariable, devices, HVDCTwoTerminalDispatch())
    add_variables!(container, HVDCLosses, devices, HVDCTwoTerminalDispatch())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerToFromVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerFromToVariable,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalDispatch},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices = get_available_components(model, sys)
    @warn "CopperPlatePowerModel models with HVDC ignores inter-area losses"
    add_constraints!(container, FlowRateConstraintFromTo, devices, model, network_model)
    add_constraints!(container, FlowRateConstraintToFrom, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    add_feedforward_constraints!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, U},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {
    T <: TwoTerminalHVDCTypes,
    U <: HVDCTwoTerminalPiecewiseLoss,
}
    devices =
        get_available_components(model, sys)
    add_variables!(
        container,
        HVDCActivePowerReceivedFromVariable,
        devices,
        HVDCTwoTerminalPiecewiseLoss(),
    )
    add_variables!(
        container,
        HVDCActivePowerReceivedToVariable,
        devices,
        HVDCTwoTerminalPiecewiseLoss(),
    )
    _add_sparse_pwl_loss_variables!(container, devices, model)
    add_to_expression!(
        container,
        ActivePowerBalance,
        HVDCActivePowerReceivedFromVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        HVDCActivePowerReceivedToVariable,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, U},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {
    T <: TwoTerminalHVDCTypes,
    U <: HVDCTwoTerminalPiecewiseLoss,
}
    devices =
        get_available_components(model, sys)
    add_constraints!(container, FlowRateConstraintFromTo, devices, model, network_model)
    add_constraints!(container, FlowRateConstraintToFrom, devices, model, network_model)
    add_constraints!(
        container,
        HVDCFlowCalculationConstraint,
        devices,
        model,
        network_model,
    )
    add_feedforward_constraints!(container, model, devices)
    return
end

# TODO: Other models besides PTDF
#=
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalPiecewiseLoss},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices =
        get_available_components(model, sys)
    add_variables!(
        container,
        FlowActivePowerToFromVariable,
        devices,
        HVDCTwoTerminalDispatch(),
    )
    add_variables!(
        container,
        FlowActivePowerFromToVariable,
        devices,
        HVDCTwoTerminalDispatch(),
    )
    add_variables!(container, HVDCFlowDirectionVariable, devices, HVDCTwoTerminalDispatch())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerToFromVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerFromToVariable,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalPiecewiseLoss},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices =
        get_available_components(model, sys)
    @warn "CopperPlatePowerModel models with HVDC ignores inter-area losses"
    add_constraints!(container, FlowRateConstraintFromTo, devices, model, network_model)
    add_constraints!(container, FlowRateConstraintToFrom, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    return
end
=#

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, HVDCTwoTerminalDispatch},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: TwoTerminalHVDCTypes}
    devices = get_available_components(model, sys)
    add_constraints!(container, FlowRateConstraintFromTo, devices, model, network_model)
    add_constraints!(container, FlowRateConstraintToFrom, devices, model, network_model)
    add_constraints!(container, HVDCPowerBalance, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    add_feedforward_constraints!(container, model, devices)
    return
end

############################# Phase Shifter Transformer Models #############################

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.PhaseShiftingTransformer, PhaseAngleControl},
    network_model::NetworkModel{PM.DCPPowerModel},
)
    devices = get_available_components(
        model,
        sys,
    )
    add_variables!(container, FlowActivePowerVariable, devices, PhaseAngleControl())
    add_variables!(container, PhaseShifterAngle, devices, PhaseAngleControl())
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.PhaseShiftingTransformer, PhaseAngleControl},
    network_model::NetworkModel{<:AbstractPTDFModel},
)
    devices = get_available_components(
        model,
        sys,
    )
    add_variables!(container, FlowActivePowerVariable, devices, PhaseAngleControl())
    add_variables!(container, PhaseShifterAngle, devices, PhaseAngleControl())
    add_to_expression!(
        container,
        ActivePowerBalance,
        PhaseShifterAngle,
        devices,
        model,
        network_model,
    )
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.PhaseShiftingTransformer, PhaseAngleControl},
    network_model::NetworkModel{PM.DCPPowerModel},
)
    devices = get_available_components(
        model,
        sys,
    )
    add_constraints!(container, FlowLimitConstraint, devices, model, network_model)
    add_constraints!(container, PhaseAngleControlLimit, devices, model, network_model)
    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    add_feedforward_constraints!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.PhaseShiftingTransformer, PhaseAngleControl},
    network_model::NetworkModel{<:AbstractPTDFModel},
)
    devices = get_available_components(
        model,
        sys,
    )
    add_constraints!(container, FlowLimitConstraint, devices, model, network_model)
    add_constraints!(container, PhaseAngleControlLimit, devices, model, network_model)
    add_constraints!(container, NetworkFlowConstraint, devices, model, network_model)
    add_constraint_dual!(container, sys, model)
    add_feedforward_constraints!(container, model, devices)
    return
end

################################# AreaInterchange Models ################################
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.AreaInterchange, U},
    network_model::NetworkModel{CopperPlatePowerModel},
) where {U <: Union{StaticBranchUnbounded, StaticBranch}}
    devices = get_available_components(model, sys)
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.AreaInterchange, StaticBranchUnbounded},
    network_model::NetworkModel{T},
) where {T <: PM.AbstractActivePowerModel}
    devices = get_available_components(model, sys)
    add_feedforward_constraints!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.AreaInterchange, T},
    network_model::NetworkModel{U},
) where {
    T <: Union{StaticBranchUnbounded, StaticBranch},
    U <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(model, sys)
    has_ts = PSY.has_time_series.(devices)
    if get_use_slacks(model)
        add_variables!(
            container,
            FlowActivePowerSlackUpperBound,
            network_model,
            devices,
            T(),
        )
        add_variables!(
            container,
            FlowActivePowerSlackLowerBound,
            network_model,
            devices,
            T(),
        )
    end
    if any(has_ts) && !all(has_ts)
        error(
            "Not all AreaInterchange devices have time series. Check data to complete (or remove) time series.",
        )
    end
    add_variables!(
        container,
        FlowActivePowerVariable,
        network_model,
        devices,
        T(),
    )
    add_to_expression!(
        container,
        ActivePowerBalance,
        FlowActivePowerVariable,
        devices,
        model,
        network_model,
    )
    if all(has_ts)
        for device in devices
            name = PSY.get_name(device)
            num_ts = length(unique(PSY.get_name.(PSY.get_time_series_keys(device))))
            if num_ts < 2
                error(
                    "AreaInterchange $name has less than two time series. It is required to add both from_to and to_from time series.",
                )
            end
        end
        add_parameters!(container, FromToFlowLimitParameter, devices, model)
        add_parameters!(container, ToFromFlowLimitParameter, devices, model)
    end
    add_feedforward_arguments!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.AreaInterchange, StaticBranch},
    network_model::NetworkModel{T},
) where {T <: PM.AbstractActivePowerModel}
    devices = get_available_components(model, sys)
    add_constraints!(container, FlowLimitConstraint, devices, model, network_model)
    add_feedforward_constraints!(container, model, devices)
    return
end

function _get_branch_map(
    container::OptimizationContainer,
    network_model::NetworkModel,
    sys::PSY.System,
)
    @assert !isempty(network_model.modeled_branch_types)

    inter_area_branch_map =
        Dict{Tuple{PSY.Area, PSY.Area}, Dict{DataType, Vector{<:PSY.ACBranch}}}()
    for branch_type in network_model.modeled_branch_types
        if branch_type == PSY.AreaInterchange
            continue
        end
        if !has_container_key(container, FlowActivePowerVariable, branch_type)
            continue
        end
        flow_vars = get_variable(container, FlowActivePowerVariable(), branch_type)
        branch_names = axes(flow_vars)[1]
        for bname in branch_names
            d = PSY.get_component(branch_type, sys, bname)
            area_from = PSY.get_area(PSY.get_arc(d).from)
            area_to = PSY.get_area(PSY.get_arc(d).to)
            if area_from != area_to
                branch_typed_dict = get!(
                    inter_area_branch_map,
                    (area_from, area_to),
                    Dict{DataType, Vector{<:PSY.ACBranch}}(),
                )
                if !haskey(branch_typed_dict, branch_type)
                    branch_typed_dict[branch_type] = [d]
                else
                    push!(branch_typed_dict[branch_type], d)
                end
            end
        end
    end
    return inter_area_branch_map
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.AreaInterchange, StaticBranch},
    network_model::NetworkModel{T},
) where {T <: PSI.AbstractPTDFModel}
    devices = get_available_components(model, sys)
    add_constraints!(container, FlowLimitConstraint, devices, model, network_model)
    # Not ideal to do this here, but it is a not terrible workaround
    # The area interchanges are like a services/device mix.
    # Doesn't include the possibility of Multi-terminal HVDC
    inter_area_branch_map = _get_branch_map(container, network_model, sys)

    add_constraints!(
        container,
        LineFlowBoundConstraint,
        devices,
        model,
        network_model,
        inter_area_branch_map,
    )
    add_feedforward_constraints!(container, model, devices)
    return
end

function construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.AreaInterchange, StaticBranchUnbounded},
    network_model::NetworkModel{AreaBalancePowerModel},
)
    add_feedforward_constraints!(container, model, devices)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.AreaInterchange, StaticBranchUnbounded},
    network_model::NetworkModel{AreaPTDFPowerModel},
)
    devices = get_available_components(model, sys)
    inter_area_branch_map = _get_branch_map(container, network_model, sys)
    # Not ideal to do this here, but it is a not terrible workaround
    # The area interchanges are like a services/device mix.
    # Doesn't include the possibility of Multi-terminal HVDC
    add_constraints!(
        container,
        LineFlowBoundConstraint,
        devices,
        model,
        network_model,
        inter_area_branch_map,
    )
    add_feedforward_constraints!(container, model, devices)
    return
end
