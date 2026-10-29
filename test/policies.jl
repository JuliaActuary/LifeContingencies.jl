@testset "priced policies and reserve columns" begin
    life = SingleLife(UltimateMortality([0.1, 0.2, 0.3, 1.0]; start_age=60))
    lc = LifeContingency(life, 0.05)
    term = NetPremiumPolicy(Insurance(lc, 2), AnnuityDue(lc, 2))
    p = (0.1/1.05 + 0.9*0.2/1.05^2) / (1 + 0.9/1.05)
    @test premium_net(term) ≈ p
    @test premium_net(life, 0.05, 2) ≈ p
    @test reserve_premium_net(term, 0) ≈ 0 atol=1e-14
    @test reserve_premium_net(term, 1) ≈ 0.2/1.05 - p
    @test reserve_premium_net(term, 1; phase=:after) ≈ 0.2/1.05
    @test reserve_premium_net(term.benefit, term.premiums, 1) ≈ 0.2/1.05 - p
    @test reserve_premium_net(term, 2:8) == zeros(7)
    @test reserve_premium_net(term, Int[]) == Float64[]
    @test reserve_premium_net(term, [2, 0, 1, 1]) ≈ [0, 0, 0.2/1.05-p, 0.2/1.05-p] atol=1e-14
    @test_throws ArgumentError reserve_premium_net(term, 0.5)
    @test_throws ArgumentError reserve_premium_net(term, [0, 0.5])
    @test_throws ArgumentError reserve_premium_net(term, Int[]; phase=:bad)
    @test_throws ArgumentError reserve_premium_net(term, 1; state=:sick)
    @test_throws ArgumentError NetPremiumPolicy(term.benefit, AnnuityDue(life, 0.03, 2))
    @test_throws ArgumentError NetPremiumPolicy(term.benefit, term.premiums; premium=NaN)
    @test_throws DomainError NetPremiumPolicy(term.benefit, AnnuityDue(lc, 0))
    @test NetPremiumPolicy(term.benefit, AnnuityDue(lc, 0); premium=0).premium == 0
    stored_premium = term.premium
    changed = LifeContingency(SingleLife(UltimateMortality([0.15, 0.3, 0.4, 1.0]; start_age=60)), 0.02)
    @test reserve_premium_net(term, 1; valuation_basis=changed) ≈ 0.3/1.02 - p
    @test premium_net(term) == stored_premium
    @test_throws ArgumentError reserve_premium_net(term, 1; valuation_basis=LifeContingency(SingleLife(life.mortality; issue_age=61), 0.02))
    @test_throws ArgumentError reserve_premium_net(term, 1; valuation_basis=0.02)

    # Independent prospective oracle, including 2-pay whole life and endowment.
    for b in (Insurance(lc), Insurance(lc, 1), Endowment(lc, 3), AnnuityDue(lc, 4; certain=2)), n in (1, 2, 4)
        policy = NetPremiumPolicy(b, AnnuityDue(lc, n))
        for phase in (:before, :after)
            column = reserve_premium_net(policy, 0:5; phase)
            for t in 0:5
                expected = present_value(b, t; state=:alive, phase) - policy.premium * present_value(policy.premiums, t; state=:alive, phase)
                @test column[t+1] ≈ expected atol=1e-14
                @test column[t+1] ≈ reserve_premium_net(policy, t; state=:alive, phase) atol=1e-14
            end
        end
    end
    short = LifeContingency(SingleLife(UltimateMortality([0.1, 0.2]; start_age=60)), 0.05)
    e = NetPremiumPolicy(Endowment(short, 2), AnnuityDue(short, 2))
    @test reserve_premium_net(e, 2) == 0
    @test reserve_premium_net(e, 1) ≈ 1/1.05 - e.premium
    @test_throws DomainError reserve_premium_net(short, 1)

    # End-period annuity premiums and monthly guaranteed benefits use their own phases.
    for constructor in (AnnuityDue, AnnuityImmediate)
        b = constructor(lc, 6; certain=5, frequency=12)
        paid_up = NetPremiumPolicy(b, AnnuityDue(lc, 1))
        for phase in (:before, :after)
            @test reserve_premium_net(paid_up, 1:6; state=:dead, phase) ≈ [present_value(b, t; state=:dead, phase) for t in 1:6]
        end
        q = NetPremiumPolicy(Insurance(lc), constructor(lc, 2; frequency=12))
        @test reserve_premium_net(q, 1; phase=:after) ≈ present_value(q.benefit, 1; state=:alive) - q.premium * present_value(q.premiums, 1; state=:alive, phase=:after)
    end
    # Explicit states may be impossible under the issue projection, yet observed later.
    extinct = LifeContingency(SingleLife(UltimateMortality([1.0, 0.2, 1.0]; start_age=60)), 0.05)
    counterfactual = NetPremiumPolicy(Insurance(extinct), AnnuityDue(extinct))
    @test_throws DomainError reserve_premium_net(counterfactual, 1)
    @test reserve_premium_net(counterfactual, [1, 2]; state=:alive) ≈ [reserve_premium_net(counterfactual, t; state=:alive) for t in 1:2]

    # Joint aggregate conditioning is the mixture of the known statuses.
    joint = JointLife(life, life; contingency=LastSurvivor())
    jlc = LifeContingency(joint, RegressionCurve())
    jp = NetPremiumPolicy(Endowment(jlc, 3), AnnuityDue(jlc, 2))
    for t in 0:2
        weights = LifeContingencies.in_force_distribution(joint, t)
        @test reserve_premium_net(jp, t) ≈ sum(q * reserve_premium_net(jp, t; state=s) for (s, q) in weights)
    end
    # An already-dead shorter life needs no extrapolation of its incomplete rates.
    dead_short = SingleLife(UltimateMortality([0.1]; start_age=60); alive=false)
    j = JointLife(dead_short, life; contingency=LastSurvivor())
    jpolicy = NetPremiumPolicy(Insurance(j, 0.05), AnnuityDue(j, 0.05))
    @test reserve_premium_net(jpolicy, 0:3) ≈ reserve_premium_net(lc, 0:3)
    precise = LifeContingency(SingleLife(UltimateMortality(BigFloat[0.1,0.2,0.3,1]; start_age=60)), big"0.05")
    bp = NetPremiumPolicy(Endowment(precise, 3), AnnuityDue(precise, 2))
    @test reserve_premium_net(bp, 0:3) isa Vector{BigFloat}
    @test reserve_premium_net(bp, 1) ≈ present_value(bp.benefit, 1; state=:alive) - bp.premium * present_value(bp.premiums, 1; state=:alive)
end

@testset "monthly premiums retain annual death settlement" begin
    life = SingleLife(UltimateMortality([0.1,0.2,0.3,1.0]; start_age=60))
    lc = LifeContingency(life, RegressionCurve())
    for frequency in (4, 12), maturity in (2, 4)
        b = Endowment(lc, maturity)
        p = NetPremiumPolicy(b, AnnuityDue(lc, 2; frequency))
        for t in 0:3, phase in (:before, :after)
            oracle = present_value(b, t; state=:alive, phase) - p.premium * present_value(p.premiums, t; state=:alive, phase)
            @test reserve_premium_net(p, t; phase) ≈ oracle atol=1e-14
        end
    end
end

struct ReserveCountedMortality <: AbstractVector{Float64}
    rates::Vector{Float64}
    reads::Base.RefValue{Int}
end
Base.size(q::ReserveCountedMortality) = size(q.rates)
Base.IndexStyle(::Type{ReserveCountedMortality}) = IndexLinear()
Base.getindex(q::ReserveCountedMortality, i::Int) = (q.reads[] += 1; q.rates[i])

@testset "reserve-column work scales with horizon" begin
    function column_reads(n)
        q = ReserveCountedMortality([fill(0.01, n-1); 1.0], Ref(0))
        lc = LifeContingency(SingleLife(q), 0.05)
        p = NetPremiumPolicy(Insurance(lc), AnnuityDue(lc))
        q.reads[] = 0
        reserve_premium_net(p, 0:n)
        return q.reads[]
    end
    @test column_reads(200) < 2.2column_reads(100)
end

struct UnderflowCurve end
FinanceCore.discount(::UnderflowCurve, t) = exp(-0.1t^2)
FinanceCore.discount(::UnderflowCurve, s, t) = exp(-0.1(t^2-s^2))
@testset "late guarantees use interval discounting" begin
    life = SingleLife(UltimateMortality([1.0]))
    lc = LifeContingency(life, UnderflowCurve())
    p = NetPremiumPolicy(AnnuityDue(lc, 101; certain=101), AnnuityDue(lc, 0); premium=0)
    @test reserve_premium_net(p, 100; state=:dead) == 1
    @test reserve_premium_net(p, 99:101; state=:dead) ≈ [1 + exp(-19.9), 1, 0]
end
