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
