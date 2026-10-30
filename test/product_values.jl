@testset "product settlement and known status" begin
    life = SingleLife(UltimateMortality([0.1, 0.2, 1.0]; start_age=60))
    lc = LifeContingency(life, 0.05)
    for product in (Insurance(lc), AnnuityDue(lc), AnnuityImmediate(lc), Endowment(lc, 2))
        @test present_value(product, 0) ≈ present_value(product)
        @test present_value(product, 0; state=:alive) ≈ present_value(product)
        @test_throws ArgumentError present_value(product, 1; phase=:unknown)
        @test_throws ArgumentError present_value(product, 1; state=:unknown)
    end
    for n in (1, 2, 3, 5)
        e = Endowment(lc, n)
        @test present_value(e) ≈ present_value(Insurance(lc, n)) + APV(lc, n)
        @test present_value(e) ≈ sum(cashflows(e) .* discount(e))
        @test present_value(e, n; state=:alive) == 0
    end
    @test_throws ArgumentError Endowment(lc, 0)
    @test_throws ArgumentError Endowment(lc, 1.5)
    @test_throws ArgumentError present_value(Insurance(lc), 0.5; state=:alive)
    short = LifeContingency(SingleLife(UltimateMortality([0.1, 0.2]; start_age=60)), 0.0)
    @test present_value(Endowment(short, 2)) ≈ 1
    @test_throws DomainError present_value(Endowment(short, 3))
    for constructor in (AnnuityDue, AnnuityImmediate)
        g = constructor(lc, 5; certain=4, frequency=12)
        for t in (0.0, 0.5, 1.0, 2.0, 4.0, 5.0), phase in (:before, :after)
            dates = collect(timepoints(g))
            expected_dead = sum(discount(lc.int, t, d) / 12 for (i, d) in enumerate(dates) if i <= 48 && (d > t || (constructor === AnnuityDue && phase === :before && d == t)); init=0.0)
            @test present_value(g, t; state=:dead, phase) ≈ expected_dead
        end
    end
    j = JointLife(life, life; contingency=LastSurvivor())
    a = AnnuityDue(j, 0.0, 3)
    @test present_value(a, 1; state=(:alive, :dead)) ≈ 1.8
    @test present_value(a, 1; state=(:alive, :alive)) ≈ 1.96
end

@testset "annuity valuation dates snap within rounding" begin
    lc = LifeContingency(SingleLife(UltimateMortality([0.1, 0.2, 1.0])), 0.04)
    for constructor in (AnnuityDue, AnnuityImmediate), certain in (0, 1)
        ann = constructor(lc, 2; frequency=10, certain)
        for state in (nothing, :alive, :dead), phase in (:before, :after)
            exact = present_value(ann, 0.3; state, phase)
            @test present_value(ann, 0.1*3; state, phase) == exact
            @test present_value(ann, prevfloat(0.3); state, phase) == exact
            @test present_value(ann, nextfloat(0.3); state, phase) == exact
        end
        # A materially later time must still exclude a due installment.
        if constructor === AnnuityDue
            @test present_value(ann, 0.3; state=:alive) > present_value(ann, 0.3 + 1e-8; state=:alive)
        end
    end
    monthly = AnnuityDue(lc, 2; frequency=12)
    @test present_value(monthly, sum(fill(1/12, 23))) ≈ present_value(monthly, 23/12)
    @test present_value(monthly, big"0.5") ≈ present_value(monthly, 0.5)
end

@testset "accumulated projection dates settle every product consistently" begin
    life = SingleLife(UltimateMortality([fill(0.01, 74); 1.0]; start_age=45))
    lc = LifeContingency(life, 0.04)
    monthly_times = Float64[]
    t = 0.0
    for k in 1:900
        t += 1/12
        push!(monthly_times, t)
    end
    for constructor in (AnnuityDue, AnnuityImmediate)
        ann = constructor(lc, 75; frequency=12, certain=10)
        for phase in (:before, :after), k in eachindex(monthly_times)
            @test present_value(ann, monthly_times[k]; phase) == present_value(ann, k/12; phase)
        end
        for state in (:alive, :dead), phase in (:before, :after), k in (1, 12, 23, 24, 120, 121, 899, 900)
            @test present_value(ann, monthly_times[k]; state, phase) == present_value(ann, k/12; state, phase)
        end
    end

    premiums = AnnuityDue(lc, 20; frequency=12)
    for product in (Insurance(lc, 20), Endowment(lc, 20))
        premium = premium_net(product, premiums)
        for state in (nothing, :alive, :dead), phase in (:before, :after), year in 1:20
            drifted = monthly_times[12year]
            exact = present_value(product, year; state, phase)
            @test present_value(product, drifted; state, phase) == exact
            @test present_value(product, drifted; state, phase) - premium * present_value(premiums, drifted; state, phase) ==
                  exact - premium * present_value(premiums, year; state, phase)
        end
    end
end

@testset "snapping retains meaningful payment-date distinctions" begin
    lc = LifeContingency(SingleLife(UltimateMortality([0.1, 0.2, 1.0])), 0.0)
    for product in (Insurance(lc, 2), Endowment(lc, 2))
        @test present_value(product, 1 - 2e-9) > present_value(product, 1)
        @test present_value(product, 1 - 0.5e-9) == present_value(product, 1)
        @test_throws ArgumentError present_value(product, 1 - 2e-9; state=:alive)
    end
    due = AnnuityDue(lc, 2; frequency=12)
    date = timepoints(due)[7]
    @test present_value(due, date + 0.5e-9/12) == present_value(due, date)
    @test present_value(due, date + 2e-9/12) < present_value(due, date)
    @test present_value(due, Float32(date)) == present_value(due, date)
    for empty in (Insurance(lc, 0), AnnuityDue(lc, 0))
        @test present_value(empty, 0.1*3) == 0
    end
    # At low precision the ulp tolerance can exceed a period. Keep the half-period cap.
    dense = AnnuityDue(lc, 1; frequency=4, start_time=64, certain=1)
    midpoint = Float16(64.125)
    @test LifeContingencies.valuation_time(dense, midpoint) == midpoint
end
