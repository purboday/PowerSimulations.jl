test_path = mktempdir()

@testset "StaticPowerLoad" begin
    models = [StaticPowerLoad, PowerLoadDispatch, PowerLoadInterruption]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [DCPPowerModel, ACPPowerModel]
    for m in models, n in networks
        device_model = DeviceModel(PowerLoad, m)
        model = DecisionModel(MockOperationProblem, n, c_sys5_il)
        mock_construct_device!(model, device_model)
        moi_tests(model, 0, 0, 0, 0, 0, false)
        psi_checkobjfun_test(model, GAEVF)
    end
end

@testset "PowerLoadDispatch DC- PF" begin
    models = [PowerLoadDispatch]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [DCPPowerModel]
    for m in models, n in networks
        device_model = DeviceModel(InterruptiblePowerLoad, m)
        model = DecisionModel(MockOperationProblem, n, c_sys5_il)
        mock_construct_device!(model, device_model)
        moi_tests(model, 24, 0, 24, 0, 0, false)
        psi_checkobjfun_test(model, GAEVF)
    end
end

@testset "PowerLoadDispatch AC- PF" begin
    models = [PowerLoadDispatch]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [ACPPowerModel]
    for m in models, n in networks
        device_model = DeviceModel(InterruptiblePowerLoad, m)
        model = DecisionModel(MockOperationProblem, n, c_sys5_il)
        mock_construct_device!(model, device_model)
        moi_tests(model, 48, 0, 24, 0, 24, false)
        psi_checkobjfun_test(model, GAEVF)
    end
end

@testset "PowerLoadDispatch AC- PF with MarketBidCost Invalid" begin
    models = [PowerLoadDispatch]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    iloadbus4 = get_component(InterruptiblePowerLoad, c_sys5_il, "IloadBus4")
    set_operation_cost!(
        iloadbus4,
        MarketBidCost(
            no_load_cost=0.0,
            start_up=(hot=0.0, warm=0.0, cold=0.0),
            shut_down=0.0,
            incremental_offer_curves = make_market_bid_curve(
                [0.0, 100.0, 200.0, 300.0, 400.0, 500.0, 600.0],
                [25.0, 25.5, 26.0, 27.0, 28.0, 30.0],
                0.0
            )
        )
        ) 
    networks = [ACPPowerModel]
    for m in models, n in networks
        device_model = DeviceModel(InterruptiblePowerLoad, m)
        model = DecisionModel(MockOperationProblem, n, c_sys5_il)
        @test_throws ErrorException mock_construct_device!(model, device_model)
    end
end

@testset "PowerLoadDispatch AC- PF with MarketBidCost" begin
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    iloadbus4 = get_component(InterruptiblePowerLoad, c_sys5_il, "IloadBus4")
    set_operation_cost!(
        iloadbus4,
        MarketBidCost(
            no_load_cost=0.0,
            start_up=(hot=0.0, warm=0.0, cold=0.0),
            shut_down=0.0,
            decremental_offer_curves = make_market_bid_curve(
                [0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0],
                [90.0, 85.0, 75.0, 70.0, 60.0, 50.0, 45.0, 40.0, 30.0, 25.0],
                0.0
            )
        )
        ) 
    template = ProblemTemplate(NetworkModel(CopperPlatePowerModel))
    set_device_model!(template, ThermalStandard, ThermalBasicUnitCommitment)
    set_device_model!(template, InterruptiblePowerLoad, PowerLoadDispatch)
    model = DecisionModel(template,
        c_sys5_il;
        name = "UC_fixed_market_bid_cost",
        optimizer = HiGHS_optimizer,
        system_to_file = false,
        optimizer_solve_log_print = true)
    @test build!(model; output_dir = test_path) == PSI.ModelBuildStatus.BUILT
    @test solve!(model) == PSI.RunStatus.SUCCESSFULLY_FINALIZED
    results = OptimizationProblemResults(model)
    expr = read_expression(results, "ProductionCostExpression__InterruptiblePowerLoad")
    p_l = read_variable(results, "ActivePowerVariable__InterruptiblePowerLoad")
    index = findfirst(row -> isapprox(100, row; atol = 1e-6), p_l.IloadBus4)
    calculated_cost = expr[index, "IloadBus4"][1]
    @test isapprox(-5700, calculated_cost; atol=1)
end

@testset "PowerLoadInterruption DC- PF" begin
    models = [PowerLoadInterruption]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [DCPPowerModel]
    for m in models, n in networks
        device_model = DeviceModel(InterruptiblePowerLoad, m)
        model = DecisionModel(MockOperationProblem, n, c_sys5_il)
        mock_construct_device!(model, device_model)
        moi_tests(model, 48, 0, 24, 0, 0, true)
        psi_checkobjfun_test(model, GAEVF)
    end
end

@testset "PowerLoadInterruption AC- PF" begin
    models = [PowerLoadInterruption]
    c_sys5_il = PSB.build_system(PSITestSystems, "c_sys5_il")
    networks = [ACPPowerModel]
    for m in models, n in networks
        device_model = DeviceModel(InterruptiblePowerLoad, m)
        model = DecisionModel(MockOperationProblem, n, c_sys5_il)
        mock_construct_device!(model, device_model)
        moi_tests(model, 72, 0, 24, 0, 24, true)
        psi_checkobjfun_test(model, GAEVF)
    end
end
