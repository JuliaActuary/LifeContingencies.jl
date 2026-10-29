@testset "priced policies and reserve columns" begin
    life = SingleLife(UltimateMortality([0.1, 0.2, 0.3, 1.0]; start_age=60))
    lc = LifeContingency(life, 0.05)
    term = PricedPolicy(Insurance(lc, 2), AnnuityDue(lc, 2))
    p = (0.1/1.05 + 0.9*0.2/1.05^2) / (1 + 0.9/1.05)
    @test term.premium ≈ p
    @test premium_net(life, 0.05, 2) ≈ p
    @test policy_value(term, 0) ≈ 0 atol=1e-14
    @test policy_value(term, 1) ≈ 0.2/1.05 - p
    @test policy_value(term, 1; phase=:after) ≈ 0.2/1.05
    @test !applicable(reserve_premium_net, term.benefit, term.premiums, 1)
    @test !applicable(reserve_premium_net, term, 1)
    @test !applicable(premium_net, term)
    @test policy_value(term, 2:8) == zeros(7)
    @test policy_value(term, Int[]) == Float64[]
    @test policy_value(term, [2, 0, 1, 1]) ≈ [0, 0, 0.2/1.05-p, 0.2/1.05-p] atol=1e-14
    @test_throws ArgumentError policy_value(term, 0.5)
    @test_throws ArgumentError policy_value(term, [0, 0.5])
    @test_throws ArgumentError policy_value(term, Int[]; phase=:bad)
    @test_throws ArgumentError policy_value(term, 1; state=:sick)
    @test_throws ArgumentError PricedPolicy(term.benefit, AnnuityDue(life, 0.03, 2))
    @test_throws ArgumentError PricedPolicy(term.benefit, term.premiums; premium=NaN)
    @test_throws DomainError PricedPolicy(term.benefit, AnnuityDue(lc, 0))
    @test PricedPolicy(term.benefit, AnnuityDue(lc, 0); premium=0).premium == 0
    stored_premium = term.premium
    changed = LifeContingency(SingleLife(UltimateMortality([0.15, 0.3, 0.4, 1.0]; start_age=60)), 0.02)
    @test policy_value(term, 1; basis=changed) ≈ 0.3/1.02 - p
    @test term.premium == stored_premium
    @test_throws ArgumentError policy_value(term, 1; basis=LifeContingency(SingleLife(life.mortality; issue_age=61), 0.02))
    @test_throws ArgumentError policy_value(term, 1; basis=0.02)

    # Independent prospective oracle, including 2-pay whole life and endowment.
    for b in (Insurance(lc), Insurance(lc, 1), Endowment(lc, 3), AnnuityDue(lc, 4; certain=2)), n in (1, 2, 4)
        policy = PricedPolicy(b, AnnuityDue(lc, n))
        for phase in (:before, :after)
            column = policy_value(policy, 0:5; phase)
            for t in 0:5
                expected = present_value(b, t; state=:alive, phase) - policy.premium * present_value(policy.premiums, t; state=:alive, phase)
                @test column[t+1] ≈ expected atol=1e-14
                @test column[t+1] ≈ policy_value(policy, t; state=:alive, phase) atol=1e-14
            end
        end
    end
    short = LifeContingency(SingleLife(UltimateMortality([0.1, 0.2]; start_age=60)), 0.05)
    e = PricedPolicy(Endowment(short, 2), AnnuityDue(short, 2))
    @test policy_value(e, 2) == 0
    @test policy_value(e, 1) ≈ 1/1.05 - e.premium
    @test_throws DomainError reserve_premium_net(short, 1)

    # End-period annuity premiums and monthly guaranteed benefits use their own phases.
    for constructor in (AnnuityDue, AnnuityImmediate)
        b = constructor(lc, 6; certain=5, frequency=12)
        paid_up = PricedPolicy(b, AnnuityDue(lc, 1))
        for phase in (:before, :after)
            @test policy_value(paid_up, 1:6; state=:dead, phase) ≈ [present_value(b, t; state=:dead, phase) for t in 1:6]
        end
        q = PricedPolicy(Insurance(lc), constructor(lc, 2; frequency=12))
        @test policy_value(q, 1; phase=:after) ≈ present_value(q.benefit, 1; state=:alive) - q.premium * present_value(q.premiums, 1; state=:alive, phase=:after)
    end
    # Explicit states may be impossible under the issue projection, yet observed later.
    extinct = LifeContingency(SingleLife(UltimateMortality([1.0, 0.2, 1.0]; start_age=60)), 0.05)
    counterfactual = PricedPolicy(Insurance(extinct), AnnuityDue(extinct))
    @test_throws DomainError policy_value(counterfactual, 1)
    @test policy_value(counterfactual, [1, 2]; state=:alive) ≈ [policy_value(counterfactual, t; state=:alive) for t in 1:2]

    # Joint aggregate conditioning is the mixture of the known statuses.
    joint = JointLife(life, life; contingency=LastSurvivor())
    jlc = LifeContingency(joint, RegressionCurve())
    jp = PricedPolicy(Endowment(jlc, 3), AnnuityDue(jlc, 2))
    for t in 0:2
        weights = LifeContingencies.in_force_distribution(joint, t)
        @test policy_value(jp, t) ≈ sum(q * policy_value(jp, t; state=s) for (s, q) in weights)
    end
    # An already-dead shorter life needs no extrapolation of its incomplete rates.
    dead_short = SingleLife(UltimateMortality([0.1]; start_age=60); alive=false)
    j = JointLife(dead_short, life; contingency=LastSurvivor())
    jpolicy = PricedPolicy(Insurance(j, 0.05), AnnuityDue(j, 0.05))
    @test policy_value(jpolicy, 0:3) ≈ reserve_premium_net(lc, 0:3)
    precise = LifeContingency(SingleLife(UltimateMortality(BigFloat[0.1,0.2,0.3,1]; start_age=60)), big"0.05")
    bp = PricedPolicy(Endowment(precise, 3), AnnuityDue(precise, 2))
    @test policy_value(bp, 0:3) isa Vector{BigFloat}
    @test policy_value(bp, 1) ≈ present_value(bp.benefit, 1; state=:alive) - bp.premium * present_value(bp.premiums, 1; state=:alive)
end

@testset "monthly premiums retain annual death settlement" begin
    life = SingleLife(UltimateMortality([0.1,0.2,0.3,1.0]; start_age=60))
    lc = LifeContingency(life, RegressionCurve())
    for frequency in (4, 12), maturity in (2, 4)
        b = Endowment(lc, maturity)
        p = PricedPolicy(b, AnnuityDue(lc, 2; frequency))
        for t in 0:3, phase in (:before, :after)
            oracle = present_value(b, t; state=:alive, phase) - p.premium * present_value(p.premiums, t; state=:alive, phase)
            @test policy_value(p, t; phase) ≈ oracle atol=1e-14
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
        p = PricedPolicy(Insurance(lc), AnnuityDue(lc))
        q.reads[] = 0
        policy_value(p, 0:n)
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
    p = PricedPolicy(AnnuityDue(lc, 101; certain=101), AnnuityDue(lc, 0); premium=0)
    @test policy_value(p, 100; state=:dead) == 1
    @test policy_value(p, 99:101; state=:dead) ≈ [1 + exp(-19.9), 1, 0]
end

@testset "retained premiums and valuation net premiums have distinct APIs" begin
    life = SingleLife(UltimateMortality([0.1,0.2,0.3,1.0]; start_age=60))
    pricing = LifeContingency(life, 0.04)
    valuation = LifeContingency(SingleLife(UltimateMortality([0.2,0.3,0.4,1.0]; start_age=60)), 0.03)
    stored = PricedPolicy(Insurance(pricing), AnnuityDue(pricing))
    recomputed = PricedPolicy(Insurance(valuation), AnnuityDue(valuation))
    @test stored.premium != recomputed.premium
    @test policy_value(stored, 1; basis=valuation) != reserve_premium_net(valuation, 1)
    @test policy_value(recomputed, 0:4) ≈ reserve_premium_net(valuation, 0:4)
    @test_throws MethodError reserve_premium_net(pricing, 1; basis=valuation)
    @test_throws ArgumentError PricedPolicy(Insurance(pricing), AnnuityDue(pricing; certain=1))
    @test_throws ArgumentError premium_net(Insurance(pricing), AnnuityDue(pricing; certain=1))
    supplied = PricedPolicy(stored.benefit, stored.premiums; premium=2stored.premium)
    @test policy_value(supplied, 0) ≈ -present_value(stored.benefit)
    @test supplied.premium == 2stored.premium
    @test !isdefined(LifeContingencies, :NetPremiumPolicy)
    err = try JointLife(life, life); catch e; e; end
    @test err isa ArgumentError
    @test occursin("FirstToDie()", sprint(showerror, err))
    @test occursin("LastSurvivor()", sprint(showerror, err))
end

@testset "typed policy columns preserve reachable and observed states" begin
    # Later observations must be seeded even after certain prior extinction.
    life = SingleLife(UltimateMortality([1.0, 1.0, 0.3, 1.0]; start_age=60))
    lc = LifeContingency(life, 0.04)
    p = PricedPolicy(Insurance(lc), AnnuityDue(lc))
    times = [2, 0, 2, 1, 4]
    @test policy_value(p, times; state=:alive) ≈ [policy_value(p, t; state=:alive) for t in times]
    # A guarantee past contingent support must not request additional living rows.
    short = LifeContingency(SingleLife(UltimateMortality([0.1, 0.2]; start_age=60)), 0.04)
    certain = PricedPolicy(AnnuityDue(short, 5; certain=5), AnnuityDue(short, 1))
    @test policy_value(certain, [2, 3, 4]; state=:alive) ≈ [present_value(certain.benefit, t; state=:alive) for t in 2:4]
    for contingency in (FirstToDie(), LastSurvivor()), numeric in (Float64, BigFloat)
        one = SingleLife(UltimateMortality(numeric.([0.1,0.2,0.3,1.0]); start_age=60))
        two = SingleLife(UltimateMortality(numeric.([0.2,0.3,0.4,1.0]); start_age=63))
        basis = LifeContingency(JointLife(one, two; contingency), numeric(0.04))
        benefit = AnnuityDue(basis, 3; frequency=12, certain=2)
        policy = PricedPolicy(benefit, AnnuityDue(basis, 2; frequency=12))
        for state in (nothing, (:alive,:alive), (:alive,:dead), (:dead,:alive), (:dead,:dead)), phase in (:before,:after)
            column = policy_value(policy, 0:4; state, phase)
            @test column isa Vector{numeric}
            @test column ≈ [policy_value(policy, t; state, phase) for t in 0:4]
            if !isnothing(state)
                oracle = [present_value(benefit, t; state, phase) - policy.premium * present_value(policy.premiums, t; state, phase) for t in 0:4]
                @test column ≈ oracle
            end
        end
    end
    bad = LifeContingency(SingleLife(UltimateMortality([-0.1,1.0])), 0.04)
    invalid = PricedPolicy(Insurance(bad), AnnuityDue(bad); premium=0)
    @test_throws ArgumentError policy_value(invalid, 0)
    @test_throws ArgumentError policy_value(invalid, 0:1)
end

@testset "column inference and allocation regression" begin
    life = SingleLife(UltimateMortality([fill(0.01,75);1.0]; start_age=45))
    lc = LifeContingency(life, 0.04)
    policy = PricedPolicy(Insurance(lc), AnnuityDue(lc))
    @test (@inferred policy_value(policy, 0:75)) isa Vector{Float64}
    @test (@inferred policy_value(policy, 10)) isa Float64
    @test policy_value(policy, [10]) == [policy_value(policy, 10)]
    offset_times = UltimateMortality([2, 0, 1]; start_age=10)
    @test policy_value(policy, offset_times) == policy_value(policy, [2, 0, 1])
    # Deliberately loose, portable budget: catches reintroduced per-date dictionaries
    # without depending on exact allocator bytes or wall-clock CI timing.
    policy_value(policy, 0:75)
    allocated_column(p) = @allocated policy_value(p, 0:75)
    allocated_column(policy)
    @test allocated_column(policy) < 512 * 76 + 8192
end

@testset "rolling buffers retain the chosen numeric type" begin
    life = SingleLife(UltimateMortality(Float32[0.1,0.2,1.0]))
    lc = LifeContingency(life, Float32(0.04))
    policy = PricedPolicy(Insurance(lc), AnnuityDue(lc); premium=Float32(0.2))
    column = policy_value(policy, 0:3)
    @test column isa Vector{Float32}
    @test column ≈ [policy_value(policy, t) for t in 0:3]
end
