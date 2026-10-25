# Known defects, recorded as broken tests. Each becomes an ordinary @test in the commit
# that fixes it (see REFACTOR_PLAN.md). The plain @tests characterize behavior to keep.

struct RegressionDependence <: LifeContingencies.JointAssumption end

struct RegressionCurve end
FinanceCore.discount(::RegressionCurve, t) = exp(-0.1t^2)
FinanceCore.discount(c::RegressionCurve, from, to) = discount(c, to) / discount(c, from)

ultimate_life(q; kwargs...) = SingleLife(UltimateMortality(q); kwargs...)

# reference net premium reserve at `t`, built prospectively from conditional probabilities
function prospective_reserve(lc, t)
    life = lc.life
    n = omega(life) - t
    benefits = sum(survival(life, t, t + k - 1) * decrement(life, t + k - 1, t + k) * discount(lc.int, t, t + k) for k in 1:n)
    premiums = sum(survival(life, t, t + k) * discount(lc.int, t, t + k) for k in 0:(n-1))
    return benefits - premium_net(lc) * premiums
end

@testset "regressions" begin
    life5 = ultimate_life([0.5, 0.5, 0.5, 0.5, 1.0])

    @testset "guarantees" begin
        # a one-year guarantee on an annuity due covers one installment, not two
        @test collect(cashflows(AnnuityDue(life5, 0.0, 3; certain=1))) ≈ [1.0, 0.5, 0.25]
        # a zero-year guarantee is no guarantee
        @test collect(cashflows(AnnuityDue(life5, 0.0, 2; certain=0, start_time=1))) ≈ [0.5, 0.25]
        # a guarantee continues past established extinction
        dead_next_year = ultimate_life([1.0])
        @test present_value(AnnuityDue(dead_next_year, 0.0; certain=3)) ≈ 3.0
        @test present_value(AnnuityDue(dead_next_year, 0.0, 3; certain=3)) ≈ 3.0
    end

    @testset "contract parameters" begin
        for frequency in (0, -1)
            @test_throws ArgumentError AnnuityDue(life5, 0.0, 3; frequency)
        end
        for ins in (Insurance(life5, 0.0, 0), AnnuityDue(life5, 0.0, 0), AnnuityImmediate(life5, 0.0, 0))
            @test present_value(ins, 0) == 0
        end
        for ins in (Insurance(life5, 0.0, 3), AnnuityDue(life5, 0.0, 3), AnnuityImmediate(life5, 0.0, 3))
            @test present_value(ins, 3) == 0
        end
    end

    @testset "life status" begin
        dead = ultimate_life([0.5, 0.5, 1.0]; alive=false)
        survivor = ultimate_life([0.1, 0.1, 1.0])
        @test survival(JointLife(lives=(dead, survivor)), 1) ≈ survival(survivor, 1)
        @test present_value(AnnuityDue(dead, 0.0)) ≈ 0.0
        @test survival(dead, 0) == 0
        @test survival(LifeContingency(dead, 0.05), 1) == 0
        # two-time survival is the mortality assumption's, for a life alive at the start
        @test survival(dead, 1, 2) == survival(ultimate_life([0.5, 0.5, 1.0]), 1, 2)
        @test survival(JointLife(lives=(dead, dead)), 0) == 0
        # conditioning on a contingency that cannot be active is undefined
        @test_throws DomainError survival(JointLife(lives=(dead, dead)), 0, 1)
    end

    @testset "joint lives" begin
        short = ultimate_life([0.1, 1.0])
        # only independence is implemented; other assumptions must not silently use it
        @test_throws ArgumentError survival(JointLife(lives=(short, short), joint_assumption=RegressionDependence()), 1)
        # joint survival infers a concrete type
        j = JointLife(lives=(short, ultimate_life([0.2, 1.0])))
        @test isconcretetype(only(Base.return_types(survival, Tuple{typeof(j),Int})))
        # the last-survivor status lasts as long as the longer life
        unequal = JointLife(lives=(ultimate_life([1.0]), ultimate_life([0.0, 0.0, 1.0])))
        @test present_value(Insurance(unequal, 0.0)) ≈ 1.0
        @test omega(unequal) == 3
        @test omega(JointLife(lives=unequal.lives, contingency=FirstToDie())) == 1
        # death cash flows stay finite after both lives are extinct
        both_extinct = JointLife(lives=(ultimate_life([1.0, 0.5, 1.0]), ultimate_life([1.0, 0.5, 1.0])))
        @test collect(cashflows(Insurance(both_extinct, 0.0))) ≈ [1.0, 0.0, 0.0]
        @test all(isfinite, cashflows(Insurance(ultimate_life([1.0, 0.5, 1.0]), 0.0)))
    end

    @testset "conditioning" begin
        # aggregate last-survivor conditioning is a mixture of the known-status cases
        single = ultimate_life([0.5, 0.5, 0.5, 1.0])
        p = survival(single, 1, 2)
        at_least_one_alive = survival(JointLife(lives=(single, single)), 1, 2)
        both_known_alive = p + p - p * p
        @test at_least_one_alive ≈ 7 / 12
        @test both_known_alive ≈ 3 / 4
        @test p ≈ 1 / 2
        @test at_least_one_alive ≈ (1 / 3) * both_known_alive + (2 / 3) * p
    end

    @testset "valuation" begin
        # the time-1 value of a death payment at time 2 uses the curve's own 1→2 discount factor
        @test present_value(Insurance(ultimate_life([0.0, 1.0]), RegressionCurve()), 1) ≈ exp(-0.3)
        # late-duration reserves keep their precision
        qs = vcat(fill(0.5, 100), [0.9, 1.0])
        lc = LifeContingency(ultimate_life(qs), 0.05)
        @test reserve_premium_net(lc, 100) ≈ prospective_reserve(lc, 100)
        precise = LifeContingency(ultimate_life(big.(qs)), big(0.05))
        @test Float64(reserve_premium_net(precise, 100)) ≈ prospective_reserve(lc, 100)
        @test reserve_premium_net(precise, 100) isa BigFloat

        # a reserve needs a contract that can be in force, and a real state
        @test_throws DomainError reserve_premium_net(LifeContingency(ultimate_life([1.0, 0.5, 1.0]), 0.05), 1)
        @test_throws ArgumentError reserve_premium_net(lc, 1; state=:sick)
        @test_throws ArgumentError reserve_premium_net(lc, -1)
        @test reserve_premium_net(lc, 1; state=:alive) ≈ reserve_premium_net(lc, 1)

        # joint lives: aggregate conditioning is a mixture of the known statuses, and they differ
        first_life = ultimate_life([0.1, 0.2, 0.3, 0.4, 1.0])
        second_life = ultimate_life([0.2, 0.3, 0.4, 1.0])
        joint = LifeContingency(JointLife(lives=(first_life, second_life)), 0.05)
        aggregate = reserve_premium_net(joint, 2)
        known = Dict(s => reserve_premium_net(joint, 2; state=s) for s in ((:alive, :alive), (:alive, :dead), (:dead, :alive)))
        @test length(unique(values(known))) == 3
        weights = LifeContingencies.in_force_distribution(joint.life, 2)
        @test aggregate ≈ sum(p * known[s] for (s, p) in weights)
        # the old subtraction formula is exact where it keeps its precision
        A, ä, P = LifeContingencies.A, LifeContingencies.ä, premium_net
        @test aggregate ≈ (A(joint) - A(joint, 2) - P(joint) * (ä(joint) - ä(joint, 2))) / APV(joint, 2)

        # scalar values fold the projection instead of collecting it, so they allocate the same
        # however long the contract runs
        long_life = ultimate_life(fill(0.01, 200))
        allocated(f) = (f(); @allocated f())
        for product in (Insurance, AnnuityDue)
            @test allocated(() -> present_value(product(long_life, 0.05, 10))) == allocated(() -> present_value(product(long_life, 0.05, 150)))
        end
    end

    @testset "parametric mortality" begin
        m = MortalityTables.Gompertz(a=0.0002, b=0.13)
        @test SingleLife(mortality=m, issue_age=40) isa SingleLife
        @test SingleLife(m, issue_age=40).mortality === m
        life = SingleLife(m, 40, true, UniformDeaths())
        @test omega(LifeContingency(life, 0.05)) == Inf
        # a law that ends at age 100.5 covers 60.5 years from age 40
        bounded = SingleLife(MortalityTables.Wittstein(m=100.5), issue_age=40)
        @test omega(bounded) == 60.5
        @test survival(bounded, omega(bounded)) == survival(bounded.mortality, 40, 100.5)
        @test_throws DomainError survival(bounded, omega(bounded) + 0.5)
        term_reference = sum(1.05^-t * (survival(m, 40, 40 + t - 1) - survival(m, 40, 40 + t)) for t in 1:10)
        @test present_value(Insurance(life, 0.05, 10)) ≈ term_reference
        # parametric mortality never reaches extinction, so whole life needs a term
        @test_throws DomainError present_value(Insurance(life, 0.05))
        # a law can end partway through a year: terms within it are valued, terms past it are undefined
        @test present_value(AnnuityDue(bounded, 0.05, 2)) ≈ 1 + survival(bounded, 1) / 1.05
        @test present_value(Insurance(bounded, 0.05, 60)) ≈ sum(1.05^-t * (survival(bounded, t - 1) - survival(bounded, t)) for t in 1:60)
        @test_throws DomainError present_value(Insurance(bounded, 0.05, 61))
        @test_throws DomainError present_value(Insurance(bounded, 0.05))
        # installments are counted against their dates, so the last one inside the law falls at 60.5
        semiannual = AnnuityDue(bounded, 0.0, 61; frequency=2)
        @test last(timepoints(semiannual)) == 60.5
        @test present_value(semiannual) ≈ sum(survival(bounded, t) for t in 0:0.5:60.5) / 2
        @test_throws DomainError present_value(AnnuityDue(bounded, 0.0, 62; frequency=2))
        @test_throws DomainError present_value(AnnuityDue(bounded, 0.0))
    end

    @testset "death benefits" begin
        # a zero term keeps its life and curve and has no payments
        none = Insurance(life5, 0.05, 0)
        @test none isa Insurance && none.life === life5
        @test isempty(timepoints(none)) && isempty(cashflows(none)) && isempty(survival(none))
        @test present_value(none) == 0
        @test isconcretetype(only(Base.return_types(Insurance, Tuple{typeof(life5),Float64,Int})))
        @test isconcretetype(only(Base.return_types(Insurance, Tuple{typeof(life5),Float64})))
        @test_throws ArgumentError Insurance(life5, 0.05, -1)
        @test_throws ArgumentError Insurance(life5, 0.05, 2.5)
        # past a table that reaches extinction a term pays nothing more; past one that doesn't, it is undefined
        @test timepoints(Insurance(life5, 0.05, 10)) == timepoints(Insurance(life5, 0.05))
        @test present_value(Insurance(life5, 0.05, 10)) ≈ present_value(Insurance(life5, 0.05))
        incomplete = ultimate_life([0.5, 0.5])
        @test present_value(Insurance(incomplete, 0.05, 2)) ≈ 0.5 / 1.05 + 0.25 / 1.05^2
        @test_throws DomainError present_value(Insurance(incomplete, 0.05, 3))
        @test_throws DomainError present_value(Insurance(incomplete, 0.05))
        # a value between settlement dates keeps claims incurred but not yet paid
        @test present_value(Insurance(ultimate_life([0.5, 1.0]), 0.0), 0.5) ≈ 1.0
    end

    @testset "annuities" begin
        # the one-time value includes the payment at issue; the value at a time excludes payments then
        two = AnnuityDue(ultimate_life([0.5, 1.0]), 0.0, 2)
        @test present_value(two) ≈ 1.5
        @test present_value(two, 0) ≈ 0.5
        # a zero term keeps its life and curve and has no payments
        none = AnnuityImmediate(life5, 0.05, 0)
        @test none isa Insurance && none.life === life5
        @test isempty(timepoints(none)) && isempty(cashflows(none)) && isempty(survival(none))
        @test present_value(none) == 0
        @test isconcretetype(only(Base.return_types(AnnuityDue, Tuple{typeof(life5),Float64,Int})))
        @test isconcretetype(only(Base.return_types(AnnuityImmediate, Tuple{typeof(life5),Float64})))
        @test_throws ArgumentError AnnuityDue(life5, 0.05; certain=-1)
        @test_throws ArgumentError AnnuityDue(life5, 0.05; start_time=-1)
        @test_throws ArgumentError AnnuityDue(life5, 0.05; frequency=2.5)
        # the schedule stays exact at monthly frequency
        monthly = timepoints(AnnuityDue(life5, 0.0, 2; frequency=12))
        @test length(monthly) == 24 && first(monthly) == 0 && last(monthly) ≈ 2 - 1 / 12
        @test length(timepoints(AnnuityImmediate(life5, 0.0, 2; frequency=12))) == 24
        # guaranteed installments need no mortality rates, even past where the rates stop
        incomplete = ultimate_life([0.5, 0.5])
        @test present_value(AnnuityDue(incomplete, 0.0, 5; certain=5)) ≈ 5.0
        @test_throws DomainError present_value(AnnuityDue(incomplete, 0.0, 5; certain=2))
        # a guarantee longer than the term is cut off at the term
        @test present_value(AnnuityDue(life5, 0.0, 2; certain=4)) ≈ 2.0
        # parametric mortality: a term annuity is valued, a life annuity needs a term
        gompertz = SingleLife(MortalityTables.Gompertz(a=0.0002, b=0.13), issue_age=40)
        @test present_value(AnnuityDue(gompertz, 0.0, 10)) ≈ sum(survival(gompertz, t) for t in 0:9)
        @test_throws DomainError present_value(AnnuityDue(gompertz, 0.0))
    end

    @testset "exports" begin
        # `insurance`, `annuity_due` and `annuity_immediate` are exported but never defined
        @test_broken all(name -> isdefined(LifeContingencies, name), names(LifeContingencies))
    end
end
