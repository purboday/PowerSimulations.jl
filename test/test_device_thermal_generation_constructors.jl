test_path = mktempdir()

@testset "Test Thermal Generation Cost Functions " begin
    test_cases = [
        ("linear_cost_test", 4664.88, ThermalBasicUnitCommitment),
        ("linear_fuel_test", 4664.88, ThermalBasicUnitCommitment),
        ("quadratic_cost_test", 3301.81, ThermalDispatchNoMin),
        ("quadratic_fuel_test", 3331.12, ThermalDispatchNoMin),
        ("pwl_io_cost_test", 3421.64, ThermalBasicUnitCommitment),
        ("pwl_io_fuel_test", 3421.64, ThermalBasicUnitCommitment),
        ("pwl_incremental_cost_test", 3424.43, ThermalBasicUnitCommitment),
        ("pwl_incremental_fuel_test", 3424.43, ThermalBasicUnitCommitment),
        ("non_convex_io_pwl_cost_test", 3047.14, ThermalBasicUnitCommitment),
    ]
    for (i, cost_reference, thermal_formulation) in test_cases
        @testset "$i" begin
            sys = build_system(PSITestSystems, "c_$(i)")
            template = ProblemTemplate(NetworkModel(CopperPlatePowerModel))
            set_device_model!(template, ThermalStandard, thermal_formulation)
            set_device_model!(template, PowerLoad, StaticPowerLoad)
            model = DecisionModel(
                template,
                sys;
                name = "UC_$(i)",
                optimizer = HiGHS_optimizer,
                system_to_file = false,
                optimizer_solve_log_print = true,
            )
            @test build!(model; output_dir = test_path) == PSI.ModelBuildStatus.BUILT
            @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
            results = OptimizationProblemResults(model)
            expr = read_expression(results, "ProductionCostExpression__ThermalStandard")
            var_unit_cost = sum(expr[!, "Test Unit"])
            @test isapprox(var_unit_cost, cost_reference; atol = 1)
            @test expr[!, "Test Unit"][end] == 0.0
        end
    end
end

#TODO: This test
#=
@testset "Test Thermal Generation Cost Functions Fuel Cost time series" begin
    test_cases = [
        "linear_fuel_test_ts",
        "quadratic_fuel_test_ts",
        "pwl_io_fuel_test_ts",
        "pwl_incremental_fuel_test_ts",
        "market_bid_cost",
    ]
    for i in test_cases
        @testset "$i" begin
            sys = build_system(PSITestSystems, "c_$(i)")
            template = ProblemTemplate(NetworkModel(CopperPlatePowerModel))
            set_device_model!(template, ThermalStandard, ThermalBasicUnitCommitment)
            #=
            model = DecisionModel(
                template,
                sys;
                name = "UC_$(i)",
                optimizer = HiGHS_optimizer,
                system_to_file = false,
            )
            @test build!(model; output_dir = test_path) == PSI.ModelBuildStatus.BUILT
            @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
            =#
        end
    end
end
=#

#=
#TODO: This test
@testset "Test Thermal Generation MarketBidCost models" begin
    test_cases = [
        ("fixed_market_bid_cost", 20532.76),
        #"market_bid_cost",
    ]
    for (i, cost_reference) in test_cases
        @testset "$i" begin
            sys = build_system(PSITestSystems, "c_$(i)")
            template = ProblemTemplate(NetworkModel(CopperPlatePowerModel))
            set_device_model!(template, ThermalStandard, ThermalBasicUnitCommitment)
            set_device_model!(template, PowerLoad, StaticPowerLoad)
            model = DecisionModel(
                template,
                sys;
                name = "UC_$(i)",
                optimizer = HiGHS_optimizer,
                system_to_file = false,
                optimizer_solve_log_print = true,
            )
            @test build!(model; output_dir = test_path) == PSI.ModelBuildStatus.BUILT
            @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
            results = OptimizationProblemResults(model)
            expr = read_expression(results, "ProductionCostExpression__ThermalStandard")
            var_unit_cost = sum(expr[!, "Test Unit1"])
            @test isapprox(var_unit_cost, cost_reference; atol = 1)
            @test expr[!, "Test Unit1"][end] == 0.0
        end
    end
end
=#

################################### Unit Commitment tests ##################################
@testset "Thermal UC With DC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalStandard),
        PSI.VariableKey(StartVariable, PSY.ThermalStandard),
        PSI.VariableKey(StopVariable, PSY.ThermalStandard),
    ]

    uc_constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "dn"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalStandard, "dn"),
    ]

    aux_variables_keys = [
        PSI.AuxVarKey(PSI.TimeDurationOff, ThermalStandard),
        PSI.AuxVarKey(PSI.TimeDurationOn, ThermalStandard),
    ]
    device_model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc)
    mock_construct_device!(model, device_model)
    moi_tests(model, 480, 0, 480, 120, 120, true)
    psi_constraint_test(model, uc_constraint_keys)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
    psi_aux_variable_test(model, aux_variables_keys)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    mock_construct_device!(model, device_model)
    moi_tests(model, 480, 0, 240, 120, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "Thermal UC With AC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalStandard),
        PSI.VariableKey(StartVariable, PSY.ThermalStandard),
        PSI.VariableKey(StopVariable, PSY.ThermalStandard),
    ]
    uc_constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "dn"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalStandard, "dn"),
    ]

    aux_variables_keys = [
        PSI.AuxVarKey(PSI.TimeDurationOff, ThermalStandard),
        PSI.AuxVarKey(PSI.TimeDurationOn, ThermalStandard),
    ]

    device_model = DeviceModel(ThermalStandard, ThermalStandardUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_uc)
    mock_construct_device!(model, device_model)
    moi_tests(model, 600, 0, 600, 240, 120, true)
    psi_constraint_test(model, uc_constraint_keys)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
    psi_aux_variable_test(model, aux_variables_keys)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 600, 0, 360, 240, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "Thermal MultiStart UC With DC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StartVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StopVariable, PSY.ThermalMultiStart),
    ]
    uc_constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "dn"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalMultiStart, "up"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalMultiStart, "dn"),
    ]
    device_model = DeviceModel(ThermalMultiStart, ThermalStandardUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 384, 0, 240, 48, 144, true)
    psi_constraint_test(model, uc_constraint_keys)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart UC With AC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StartVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StopVariable, PSY.ThermalMultiStart),
    ]
    uc_constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "dn"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalMultiStart, "up"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalMultiStart, "dn"),
    ]
    device_model = DeviceModel(ThermalMultiStart, ThermalStandardUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 432, 0, 288, 96, 144, true)
    psi_constraint_test(model, uc_constraint_keys)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
end

################################### Basic Unit Commitment tests ############################
@testset "Thermal Basic UC With DC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalStandard),
        PSI.VariableKey(StartVariable, PSY.ThermalStandard),
        PSI.VariableKey(StopVariable, PSY.ThermalStandard),
    ]
    device_model = DeviceModel(ThermalStandard, ThermalBasicUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc)
    mock_construct_device!(model, device_model)
    moi_tests(model, 480, 0, 240, 120, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 480, 0, 240, 120, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "Thermal Basic UC With AC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalStandard),
        PSI.VariableKey(StartVariable, PSY.ThermalStandard),
        PSI.VariableKey(StopVariable, PSY.ThermalStandard),
    ]
    device_model = DeviceModel(ThermalStandard, ThermalBasicUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_uc)
    mock_construct_device!(model, device_model)
    moi_tests(model, 600, 0, 360, 240, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 600, 0, 360, 240, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "Thermal MultiStart Basic UC With DC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StartVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StopVariable, PSY.ThermalMultiStart),
    ]
    device_model = DeviceModel(ThermalMultiStart, ThermalBasicUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 384, 0, 96, 48, 144, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart Basic UC With AC - PF" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StartVariable, PSY.ThermalMultiStart),
        PSI.VariableKey(StopVariable, PSY.ThermalMultiStart),
    ]
    device_model = DeviceModel(ThermalMultiStart, ThermalBasicUnitCommitment)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 432, 0, 144, 96, 144, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
end

################################### Basic Dispatch tests ###################################
@testset "ThermalStandard with ThermalBasicDispatch With DC - PF" begin
    device_model = DeviceModel(ThermalStandard, ThermalBasicDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 120, 0, 120, 120, 0, false)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    mock_construct_device!(model, device_model)
    moi_tests(model, 120, 0, 120, 120, 0, false)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "ThermalStandard  with ThermalBasicDispatch With AC - PF" begin
    device_model = DeviceModel(ThermalStandard, ThermalBasicDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")

    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 240, 240, 0, false)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 240, 240, 0, false)
    psi_checkobjfun_test(model, GQEVF)
end

# This Formulation is currently broken
@testset "ThermalMultiStart with ThermalBasicDispatch With DC - PF" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalBasicDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 48, 48, 96, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "ThermalMultiStart with ThermalBasicDispatch With AC - PF" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalBasicDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 288, 0, 96, 96, 96, false)
    psi_checkobjfun_test(model, GAEVF)
end

################################### No Minimum Dispatch tests ##############################
@testset "Thermal Dispatch NoMin With DC - PF" begin
    device_model = DeviceModel(ThermalStandard, ThermalDispatchNoMin)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 120, 0, 120, 120, 0, false)
    key = PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, ThermalStandard, "lb")
    moi_lbvalue_test(model, key, 0.0)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")

    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    mock_construct_device!(model, device_model)
    moi_tests(model, 120, 0, 120, 120, 0, false)
    key = PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, ThermalStandard, "lb")
    moi_lbvalue_test(model, key, 0.0)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "Thermal Dispatch NoMin With AC - PF" begin
    device_model = DeviceModel(ThermalStandard, ThermalDispatchNoMin)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 240, 240, 0, false)
    key = PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, ThermalStandard, "lb")
    moi_lbvalue_test(model, key, 0.0)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")

    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 240, 240, 0, false)
    key = PSI.ConstraintKey(ActivePowerVariableLimitsConstraint, ThermalStandard, "lb")
    moi_lbvalue_test(model, key, 0.0)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "Thermal Dispatch NoMin With DC - PF" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalDispatchNoMin)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    @test_throws IS.ConflictingInputsError mock_construct_device!(model, device_model)
end

@testset "ThermalMultiStart Dispatch NoMin With AC - PF" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalDispatchNoMin)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5;)
    @test_throws IS.ConflictingInputsError mock_construct_device!(model, device_model)
end

@testset "Operation Model ThermalDispatchNoMin - and PWL Non Convex" begin
    c_sys5_pwl_ed_nonconvex = PSB.build_system(PSITestSystems, "c_sys5_pwl_ed_nonconvex")
    template = get_thermal_dispatch_template_network()
    set_device_model!(template, DeviceModel(ThermalStandard, ThermalDispatchNoMin))
    model = DecisionModel(
        MockOperationProblem,
        CopperPlatePowerModel,
        c_sys5_pwl_ed_nonconvex;
        export_pwl_vars = true,
        initialize_model = false,
    )
    @test_throws IS.InvalidValue mock_construct_device!(
        model,
        DeviceModel(ThermalStandard, ThermalDispatchNoMin),
    )
end

################################## Ramp Limited Testing ##################################
@testset "ThermalStandard with ThermalStandardDispatch With DC - PF" begin
    constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "dn"),
    ]
    device_model = DeviceModel(ThermalStandard, ThermalStandardDispatch)
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 120, 0, 168, 168, 0, false)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 120, 0, 120, 120, 0, false)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "ThermalStandard with ThermalStandardDispatch With AC - PF" begin
    constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "dn"),
    ]
    device_model = DeviceModel(ThermalStandard, ThermalStandardDispatch)
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 288, 288, 0, false)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys14;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 240, 240, 0, false)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "ThermalMultiStart with ThermalStandardDispatch With DC - PF" begin
    constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "dn"),
    ]
    device_model = DeviceModel(ThermalMultiStart, ThermalStandardDispatch)
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 240, 0, 96, 96, 96, false)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "ThermalMultiStart with ThermalStandardDispatch With AC - PF" begin
    constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalMultiStart, "dn"),
    ]
    device_model = DeviceModel(ThermalMultiStart, ThermalStandardDispatch)
    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_uc;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 288, 0, 144, 144, 96, false)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)
end

################################### ThermalMultiStart Testing ##############################

@testset "Thermal MultiStart with MultiStart UC and DC - PF" begin
    constraint_keys = [
        PSI.ConstraintKey(ActiveRangeICConstraint, PSY.ThermalMultiStart),
        PSI.ConstraintKey(StartTypeConstraint, PSY.ThermalMultiStart),
        PSI.ConstraintKey(
            StartupTimeLimitTemperatureConstraint,
            PSY.ThermalMultiStart,
            "warm",
        ),
        PSI.ConstraintKey(
            StartupTimeLimitTemperatureConstraint,
            PSY.ThermalMultiStart,
            "hot",
        ),
        PSI.ConstraintKey(
            StartupInitialConditionConstraint,
            PSY.ThermalMultiStart,
            "lb",
        ),
        PSI.ConstraintKey(
            StartupInitialConditionConstraint,
            PSY.ThermalMultiStart,
            "ub",
        ),
    ]
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalMultiStartUnitCommitment)
    no_less_than = Dict(true => 334, false => 282)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 528, 0, no_less_than[false], 108, 192, true)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with MultiStart UC and AC - PF" begin
    constraint_keys = [
        PSI.ConstraintKey(ActiveRangeICConstraint, PSY.ThermalMultiStart),
        PSI.ConstraintKey(StartTypeConstraint, PSY.ThermalMultiStart),
        PSI.ConstraintKey(
            StartupTimeLimitTemperatureConstraint,
            PSY.ThermalMultiStart,
            "warm",
        ),
        PSI.ConstraintKey(
            StartupTimeLimitTemperatureConstraint,
            PSY.ThermalMultiStart,
            "hot",
        ),
        PSI.ConstraintKey(
            StartupInitialConditionConstraint,
            PSY.ThermalMultiStart,
            "lb",
        ),
        PSI.ConstraintKey(
            StartupInitialConditionConstraint,
            PSY.ThermalMultiStart,
            "ub",
        ),
    ]
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalMultiStartUnitCommitment)
    no_less_than = Dict(true => 382, false => 330)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 576, 0, no_less_than[false], 156, 192, true)
    psi_constraint_test(model, constraint_keys)
    psi_checkobjfun_test(model, GAEVF)
end

################################ Thermal Compact UC Testing ################################
@testset "Thermal Standard with Compact UC and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactUnitCommitment)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 480, 0, 480, 120, 120, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact UC and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactUnitCommitment)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 384, 0, 240, 48, 144, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal Standard with Compact UC and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactUnitCommitment)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 600, 0, 600, 240, 120, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact UC and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactUnitCommitment)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 432, 0, 288, 96, 144, true)
    psi_checkobjfun_test(model, GAEVF)
end

################################ Thermal Basic Compact UC Testing ################################
@testset "Thermal Standard with Compact UC and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalBasicCompactUnitCommitment)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 480, 0, 240, 120, 120, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact UC and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalBasicCompactUnitCommitment)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 384, 0, 96, 48, 144, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal Standard with Compact UC and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalBasicCompactUnitCommitment)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model)
    moi_tests(model, 600, 0, 360, 240, 120, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact UC and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalBasicCompactUnitCommitment)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_pglib;)
    mock_construct_device!(model, device_model)
    moi_tests(model, 432, 0, 144, 96, 144, true)
    psi_checkobjfun_test(model, GAEVF)
end

############################ Thermal Compact Dispatch Testing ##############################
@testset "Thermal Standard with Compact Dispatch and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 245, 0, 144, 144, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact Dispatch and DC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactDispatch)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_pglib)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 290, 0, 96, 96, 96, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal Standard with Compact Dispatch and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactDispatch)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 365, 0, 264, 264, 0, false)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal MultiStart with Compact Dispatch and AC - PF" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactDispatch)
    c_sys5_pglib = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, ACPPowerModel, c_sys5_pglib)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 338, 0, 144, 144, 96, false)
    psi_checkobjfun_test(model, GAEVF)
end

############################# Model validation tests #######################################
@testset "Solving ED with CopperPlate for testing Ramping Constraints" begin
    ramp_test_sys = PSB.build_system(PSITestSystems, "c_ramp_test")
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, ThermalStandard, ThermalStandardDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    ED = DecisionModel(
        EconomicDispatchProblem,
        template,
        ramp_test_sys;
        optimizer = HiGHS_optimizer,
        initialize_model = false,
    )
    @test build!(ED; output_dir = mktempdir(; cleanup = true)) == PSI.ModelBuildStatus.BUILT
    moi_tests(ED, 10, 0, 15, 15, 5, false)
    psi_checksolve_test(ED, [MOI.OPTIMAL], 11191.00)
end

# Testing Duration Constraints
@testset "Solving UC with CopperPlate for testing Duration Constraints" begin
    template = get_thermal_standard_uc_template()
    UC = DecisionModel(
        UnitCommitmentProblem,
        template,
        PSB.build_system(PSITestSystems, "c_duration_test");
        optimizer = HiGHS_optimizer,
        initialize_model = false,
        store_variable_names = true,
    )
    build!(UC; output_dir = mktempdir(; cleanup = true))
    @test build!(UC; output_dir = mktempdir(; cleanup = true)) == PSI.ModelBuildStatus.BUILT
    moi_tests(UC, 56, 0, 56, 14, 21, true)
    psi_checksolve_test(UC, [MOI.OPTIMAL], 8223.50)
end

#= Test disabled due to inconsistency between the models and the data
@testset "UC with MarketBid Cost in ThermalGenerators" begin
    sys = PSB.build_system(PSITestSystems, "c_market_bid_cost")
    template = get_thermal_standard_uc_template()
    set_device_model!(
        template,
        DeviceModel(ThermalMultiStart, ThermalMultiStartUnitCommitment),
    )
    UC = DecisionModel(
        UnitCommitmentProblem,
        template,
        sys;
        optimizer = HiGHS_optimizer,
        initialize_model = false,
    )
    @test build!(UC; output_dir = mktempdir(; cleanup = true)) == PSI.ModelBuildStatus.BUILT
    moi_tests(UC, 38, 0, 16, 8, 16, true)
end
=#

@testset "Solving UC Models with Linear Networks" begin
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    c_sys5_dc = PSB.build_system(PSITestSystems, "c_sys5_dc")
    systems = [c_sys5, c_sys5_dc]
    networks = [DCPPowerModel, NFAPowerModel, PTDFPowerModel, CopperPlatePowerModel]
    commitment_models = [ThermalStandardUnitCommitment, ThermalCompactUnitCommitment]

    for net in networks, sys in systems, model in commitment_models
        template = get_thermal_dispatch_template_network(
            NetworkModel(net),
        )
        set_device_model!(template, ThermalStandard, model)
        UC = DecisionModel(template, sys; optimizer = HiGHS_optimizer)
        @test build!(UC; output_dir = mktempdir(; cleanup = true)) ==
              PSI.ModelBuildStatus.BUILT
        psi_checksolve_test(UC, [MOI.OPTIMAL, MOI.LOCALLY_SOLVED], 340000, 100000)
    end
end

@testset "Test Feedforwards to ThermalStandard with ThermalStandardDispatch" begin
    device_model = DeviceModel(ThermalStandard, ThermalStandardDispatch)
    ff_sc = SemiContinuousFeedforward(;
        component_type = ThermalStandard,
        source = OnVariable,
        affected_values = [ActivePowerVariable],
    )

    ff_ub = UpperBoundFeedforward(;
        component_type = ThermalStandard,
        source = ActivePowerVariable,
        affected_values = [ActivePowerVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 365, 0, 264, 144, 0, false)
end

@testset "Test Feedforwards to ThermalStandard with ThermalBasicDispatch" begin
    device_model = DeviceModel(ThermalStandard, ThermalBasicDispatch)
    ff_sc = SemiContinuousFeedforward(;
        component_type = ThermalStandard,
        source = OnVariable,
        affected_values = [ActivePowerVariable],
    )

    ff_ub = UpperBoundFeedforward(;
        component_type = ThermalStandard,
        source = ActivePowerVariable,
        affected_values = [ActivePowerVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 360, 0, 240, 120, 0, false)
end

@testset "Test Feedforwards to ThermalStandard with ThermalCompactDispatch" begin
    device_model = DeviceModel(PSY.ThermalStandard, PSI.ThermalCompactDispatch)
    ff_sc = SemiContinuousFeedforward(;
        component_type = ThermalStandard,
        source = OnVariable,
        affected_values = [PowerAboveMinimumVariable],
    )

    ff_ub = UpperBoundFeedforward(;
        component_type = ThermalStandard,
        source = PSI.PowerAboveMinimumVariable,
        affected_values = [PSI.PowerAboveMinimumVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 365, 0, 264, 144, 0, false)
end

@testset "Test Feedforwards to ThermalMultiStart with ThermalStandardDispatch" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalStandardDispatch)
    ff_sc = SemiContinuousFeedforward(;
        component_type = ThermalMultiStart,
        source = OnVariable,
        affected_values = [ActivePowerVariable],
    )

    ff_ub = UpperBoundFeedforward(;
        component_type = ThermalMultiStart,
        source = ActivePowerVariable,
        affected_values = [ActivePowerVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 338, 0, 144, 96, 96, false)
end

@testset "Test Feedforwards to ThermalMultiStart with ThermalBasicDispatch" begin
    device_model = DeviceModel(ThermalMultiStart, ThermalBasicDispatch)
    ff_sc = SemiContinuousFeedforward(;
        component_type = ThermalMultiStart,
        source = OnVariable,
        affected_values = [ActivePowerVariable],
    )

    ff_ub = UpperBoundFeedforward(;
        component_type = ThermalMultiStart,
        source = ActivePowerVariable,
        affected_values = [ActivePowerVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 336, 0, 96, 48, 96, false)
end

@testset "Test Feedforwards to ThermalMultiStart with ThermalCompactDispatch" begin
    device_model = DeviceModel(PSY.ThermalMultiStart, PSI.ThermalCompactDispatch)
    ff_sc = SemiContinuousFeedforward(;
        component_type = ThermalMultiStart,
        source = OnVariable,
        affected_values = [PSI.PowerAboveMinimumVariable],
    )

    ff_ub = UpperBoundFeedforward(;
        component_type = ThermalMultiStart,
        source = PSI.PowerAboveMinimumVariable,
        affected_values = [PSI.PowerAboveMinimumVariable],
    )

    PSI.attach_feedforward!(device_model, ff_sc)
    PSI.attach_feedforward!(device_model, ff_ub)
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5_pglib")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5)
    mock_construct_device!(model, device_model; built_for_recurrent_solves = true)
    moi_tests(model, 338, 0, 144, 96, 96, false)
end

@testset "Test Must Run ThermalGen" begin
    sys_5 = build_system(PSITestSystems, "c_sys5_uc")
    template_uc =
        ProblemTemplate(NetworkModel(CopperPlatePowerModel))
    set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
    #set_device_model!(template_uc, RenewableDispatch, FixedOutput)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, DeviceModel(Line, StaticBranchUnbounded))

    # Set Must Run the most expensive one: Sundance
    sundance = get_component(ThermalStandard, sys_5, "Sundance")
    set_must_run!(sundance, true)
    for rebuild in [true, false]
        model = DecisionModel(
            template_uc,
            sys_5;
            name = "UC",
            optimizer = HiGHS_optimizer,
            system_to_file = false,
            store_variable_names = true,
            rebuild_model = rebuild,
        )

        solve!(model; output_dir = mktempdir())
        ptdf_vars = get_variable_values(OptimizationProblemResults(model))
        power =
            ptdf_vars[PowerSimulations.VariableKey{ActivePowerVariable, ThermalStandard}(
                "",
            )]
        on = ptdf_vars[PowerSimulations.VariableKey{OnVariable, ThermalStandard}("")]
        start = ptdf_vars[PowerSimulations.VariableKey{StartVariable, ThermalStandard}("")]
        stop = ptdf_vars[PowerSimulations.VariableKey{StopVariable, ThermalStandard}("")]
        power_sundance = power[!, "Sundance"]
        @test all(power_sundance .>= 1.0)
        for v in [on, start, stop]
            @test "Sundance" ∉ names(v)
        end
    end
end

@testset "Thermal with max_active_power time series" begin
    device_model = DeviceModel(
        ThermalStandard,
        ThermalStandardUnitCommitment;
        time_series_names = Dict(ActivePowerTimeSeriesParameter => "max_active_power"))
    c_sys5 = PSB.build_system(PSITestSystems, "c_sys5")

    derate_data = SortedDict{Dates.DateTime, TimeSeries.TimeArray}()
    data_ts = collect(
        DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
            "1/1/2024  23:00:00",
            "d/m/y  H:M:S",
        ),
    )
    for t in 1:2
        ini_time = data_ts[1] + Day(t - 1)
        derate_data[ini_time] =
            TimeArray(data_ts + Day(t - 1), fill!(Vector{Float64}(undef, 24), 0.8))
    end
    solitude = get_component(ThermalStandard, c_sys5, "Solitude")
    PSY.add_time_series!(
        c_sys5,
        solitude,
        PSY.Deterministic("max_active_power", derate_data),
    )

    model = DecisionModel(
        MockOperationProblem,
        DCPPowerModel,
        c_sys5)

    mock_construct_device!(model, device_model)
    moi_tests(model, 480, 0, 504, 120, 120, true)
    key = PSI.ConstraintKey(
        ActivePowerVariableTimeSeriesLimitsConstraint,
        ThermalStandard,
        "ub",
    )
    constraint = PSI.get_constraint(PSI.get_optimization_container(model), key)
    ub_value = get_max_active_power(solitude) * 0.8
    for ix in eachindex(constraint)
        @test JuMP.normalized_rhs(constraint[ix]) == ub_value
    end
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Thermal with fuel cost time series" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_re_fuel_cost")

    template = ProblemTemplate(
        NetworkModel(
            CopperPlatePowerModel;
            duals = [CopperPlateBalanceConstraint],
        ),
    )

    set_device_model!(template, ThermalStandard, ThermalDispatchNoMin)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)

    model = DecisionModel(
        template,
        sys;
        name = "UC",
        optimizer = HiGHS_optimizer,
        system_to_file = false,
        store_variable_names = true,
        optimizer_solve_log_print = false,
    )
    models = SimulationModels(;
        decision_models = [
            model,
        ],
    )
    sequence = SimulationSequence(;
        models = models,
        feedforwards = Dict(
        ),
        ini_cond_chronology = InterProblemChronology(),
    )

    sim = Simulation(;
        name = "compact_sim",
        steps = 2,
        models = models,
        sequence = sequence,
        initial_time = DateTime("2024-01-01T00:00:00"),
        simulation_folder = mktempdir(),
    )

    build!(sim; console_level = Logging.Error, serialize = false)
    moi_tests(model, 432, 0, 192, 120, 72, false)
    execute!(sim; enable_progress_bar = true)

    sim_res = SimulationResults(sim)
    res_uc = get_decision_problem_results(sim_res, "UC")
    th_uc = read_realized_variable(res_uc, "ActivePowerVariable__ThermalStandard")
    p_brighton = th_uc[!, "Brighton"]
    p_solitude = th_uc[!, "Solitude"]

    @test sum(p_brighton[1:24]) < 50.0 # Barely used when expensive
    @test sum(p_brighton[25:48]) > 5000.0 # Used a lot when cheap
    @test sum(p_solitude[1:24]) > 5000.0 # Used a lot when cheap
    @test sum(p_solitude[25:48]) < 50.0 # Barely used when expensive
end

@testset "Thermal with fuel cost time series with Quadratic and PWL" begin
    sys = PSB.build_system(PSITestSystems, "c_sys5_re_fuel_cost")

    template = ProblemTemplate(
        NetworkModel(
            CopperPlatePowerModel;
            duals = [CopperPlateBalanceConstraint],
        ),
    )

    solitude = get_component(ThermalStandard, sys, "Solitude")
    op_cost = get_operation_cost(solitude)
    ts = deepcopy(get_time_series(Deterministic, solitude, "fuel_cost"))
    remove_time_series!(sys, Deterministic, solitude, "fuel_cost")
    quad_curve = QuadraticCurve(0.05, 1.0, 0.0)
    new_th_cost = ThermalGenerationCost(;
        variable = FuelCurve(;
            value_curve = quad_curve,
            fuel_cost = 1.0,
        ),
        fixed = op_cost.fixed,
        start_up = op_cost.start_up,
        shut_down = op_cost.shut_down,
    )

    set_operation_cost!(solitude, new_th_cost)
    add_time_series!(
        sys,
        solitude,
        ts,
    )

    # There is no free MIQP solver, we need to use ThermalDisptchNoMin for testing
    set_device_model!(template, ThermalStandard, ThermalDispatchNoMin)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)

    model = DecisionModel(
        template,
        sys;
        name = "UC",
        optimizer = ipopt_optimizer,
        system_to_file = false,
        store_variable_names = true,
        optimizer_solve_log_print = false,
    )
    @test build!(model; output_dir = mktempdir(; cleanup = true)) ==
          PSI.ModelBuildStatus.BUILT
    solve!(model)
    moi_tests(model, 288, 0, 192, 120, 72, false)
    container = PSI.get_optimization_container(model)
    @test isa(
        PSI.get_invariant_terms(PSI.get_objective_expression(container)),
        JuMP.QuadExpr,
    )
end

@testset "Thermal UC With Slack on Ramps" begin
    bin_variable_keys = [
        PSI.VariableKey(OnVariable, PSY.ThermalStandard),
        PSI.VariableKey(StartVariable, PSY.ThermalStandard),
        PSI.VariableKey(StopVariable, PSY.ThermalStandard),
    ]

    uc_constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "dn"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(DurationConstraint, PSY.ThermalStandard, "dn"),
    ]

    aux_variables_keys = [
        PSI.AuxVarKey(PSI.TimeDurationOff, ThermalStandard),
        PSI.AuxVarKey(PSI.TimeDurationOn, ThermalStandard),
    ]
    # Unit Commitment #
    device_model =
        DeviceModel(ThermalStandard, ThermalStandardUnitCommitment; use_slacks = true)

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc)
    mock_construct_device!(model, device_model)
    moi_tests(model, 720, 0, 480, 120, 120, true)
    psi_constraint_test(model, uc_constraint_keys)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GAEVF)
    psi_aux_variable_test(model, aux_variables_keys)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    mock_construct_device!(model, device_model)
    moi_tests(model, 720, 0, 240, 120, 120, true)
    psi_checkbinvar_test(model, bin_variable_keys)
    psi_checkobjfun_test(model, GQEVF)

    # Dispatch #
    device_model =
        DeviceModel(ThermalStandard, ThermalStandardDispatch; use_slacks = true)
    uc_constraint_keys = [
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "up"),
        PSI.ConstraintKey(RampConstraint, PSY.ThermalStandard, "dn"),
    ]

    c_sys5_uc = PSB.build_system(PSITestSystems, "c_sys5_uc")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys5_uc)
    mock_construct_device!(model, device_model)
    moi_tests(model, 360, 0, 168, 168, 0, false)
    psi_constraint_test(model, uc_constraint_keys)
    psi_checkobjfun_test(model, GAEVF)

    c_sys14 = PSB.build_system(PSITestSystems, "c_sys14")
    model = DecisionModel(MockOperationProblem, DCPPowerModel, c_sys14)
    mock_construct_device!(model, device_model)
    moi_tests(model, 360, 0, 120, 120, 0, false)
    psi_checkobjfun_test(model, GQEVF)
end

@testset "ThermalDispatchNoMin with PWL Costs" begin
    sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")

    template = ProblemTemplate(NetworkModel(PTDFPowerModel))
    set_device_model!(template, ThermalStandard, ThermalDispatchNoMin)
    set_device_model!(template, Line, StaticBranchBounds)
    set_device_model!(template, TapTransformer, StaticBranchBounds)
    set_device_model!(template, Transformer2W, StaticBranchBounds)
    set_device_model!(template, PowerLoad, StaticPowerLoad)

    solver = HiGHS_optimizer
    problem = DecisionModel(template, sys;
        optimizer = solver,
        horizon = Hour(1),
        optimizer_solve_log_print = true,
        calculate_conflict = true,
        store_variable_names = true,
        detailed_optimizer_stats = false,
    )

    build!(problem; output_dir = mktempdir())

    solve!(problem)

    res = OptimizationProblemResults(problem)

    # Test that plant 101_STEAM_3 (using max power) have proper cost expression
    cost = read_expression(res, "ProductionCostExpression__ThermalStandard")
    p_th = read_variable(res, "ActivePowerVariable__ThermalStandard")
    steam3 = get_component(ThermalStandard, sys, "101_STEAM_3")
    val_curve = PSY.get_value_curve(PSY.get_variable(PSY.get_operation_cost(steam3)))
    io_curve = InputOutputCurve(val_curve)
    fuel_cost = PSY.get_fuel_cost(steam3)
    x_last = last(io_curve.function_data.points).x
    y_last = last(io_curve.function_data.points).y * fuel_cost
    p_steam3 = p_th[!, "101_STEAM_3"]
    cost_steam3 = cost[!, "101_STEAM_3"]
    @test isapprox(p_steam3[1], x_last) # max
    @test isapprox(cost_steam3[1], y_last) # last cost
end
