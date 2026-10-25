# Known defects, recorded as broken tests. Each becomes an ordinary @test in the commit
# that fixes it (see REFACTOR_PLAN.md). The plain @tests characterize behavior to keep.

struct RegressionDependence <: LifeContingencies.JointAssumption end

struct RegressionCurve end
FinanceCore.discount(::RegressionCurve, t) = exp(-0.1t^2)
FinanceCore.discount(c::RegressionCurve, from, to) = discount(c, to) / discount(c, from)

ultimate_life(q; kwargs...) = SingleLife(UltimateMortality(q); kwargs...)

function threw(f)
    try
        f()
        return false
    catch
        return true
    end
end

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
        @test_broken collect(cashflows(AnnuityDue(life5, 0.0, 3; certain=1))) ≈ [1.0, 0.5, 0.25]
        # a zero-year guarantee is no guarantee
        @test_broken collect(cashflows(AnnuityDue(life5, 0.0, 2; certain=0, start_time=1))) ≈ [0.5, 0.25]
        # a guarantee continues past established extinction
        dead_next_year = ultimate_life([1.0])
        @test_broken present_value(AnnuityDue(dead_next_year, 0.0; certain=3)) ≈ 3.0
        @test present_value(AnnuityDue(dead_next_year, 0.0, 3; certain=3)) ≈ 3.0
    end

    @testset "contract parameters" begin
        for frequency in (0, -1)
            @test_broken threw(() -> AnnuityDue(life5, 0.0, 3; frequency))
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
        @test_broken collect(cashflows(Insurance(both_extinct, 0.0))) ≈ [1.0, 0.0, 0.0]
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
        @test_broken present_value(Insurance(ultimate_life([0.0, 1.0]), RegressionCurve()), 1) ≈ exp(-0.3)
        # late-duration reserves keep their precision
        qs = vcat(fill(0.5, 100), [0.9, 1.0])
        lc = LifeContingency(ultimate_life(qs), 0.05)
        @test_broken reserve_premium_net(lc, 100) ≈ prospective_reserve(lc, 100)
        precise = LifeContingency(ultimate_life(big.(qs)), big(0.05))
        @test Float64(reserve_premium_net(precise, 100)) ≈ prospective_reserve(lc, 100)
    end

    @testset "parametric mortality" begin
        m = MortalityTables.Gompertz(a=0.0002, b=0.13)
        @test SingleLife(mortality=m, issue_age=40) isa SingleLife
        @test SingleLife(m, issue_age=40).mortality === m
        life = SingleLife(m, 40, true, UniformDeaths())
        @test omega(LifeContingency(life, 0.05)) == Inf
        term_reference = sum(1.05^-t * (survival(m, 40, 40 + t - 1) - survival(m, 40, 40 + t)) for t in 1:10)
        @test_broken present_value(Insurance(life, 0.05, 10)) ≈ term_reference
    end

    @testset "exports" begin
        # `insurance`, `annuity_due` and `annuity_immediate` are exported but never defined
        @test_broken all(name -> isdefined(LifeContingencies, name), names(LifeContingencies))
    end
end
