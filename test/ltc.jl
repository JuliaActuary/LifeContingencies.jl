import Random

include(joinpath(@__DIR__, "..", "examples", "ltc_model.jl"))

# Monte Carlo: follow one sampled path through the rows and add up its discounted payments.
scheduled(c::StatePayment, t, state) = c.f(t, state)
scheduled(c, t, state) = 0.0
on_transition(c::TransitionPayment, interval, from, to) = c.f(interval, from, to)
on_transition(c, interval, from, to) = 0.0

function sample_next(row, u)
    cumulative, chosen = 0.0, nothing
    for (state, p) in row
        iszero(p) && continue
        cumulative += p
        chosen = state
        u < cumulative && return state
    end
    return chosen # rounding left u above the total
end

function simulated_value(contract, model, curve, grid, start, rng)
    state = start
    totals = map(_ -> 0.0, contract)
    for k in eachindex(grid)
        totals = map((total, c) -> total + scheduled(c, grid[k], state) * discount(curve, grid[1], grid[k]), totals, contract)
        k == lastindex(grid) && break
        interval = Interval(grid[k], grid[k+1])
        next = sample_next(transitions(model, interval, state), rand(rng))
        totals = map((total, c) -> total + on_transition(c, interval, state, next) * discount(curve, grid[1], grid[k+1]), totals, contract)
        state = next
    end
    return totals
end

function row_probabilities(model, interval, state)
    row = Dict{LTCState,Float64}()
    for (next, p) in transitions(model, interval, state)
        row[next] = get(row, next, 0.0) + p
    end
    return row
end

@testset "academic LTC reference" begin
    m = LTCModel()
    curve = 0.04

    @testset "reduces to a single life without incidence or lapse" begin
        healthy_only = LTCModel(incidence=0.0, lapse=0.0)
        term = 10
        forces = [healthy_only.healthy_mortality * exp(healthy_only.mortality_growth * k) for k in 0:term]
        single = SingleLife(UltimateMortality(1 .- exp.(-forces), start_age=healthy_only.issue_age); fractional_assump=ConstantForce())
        grid = months(term)
        p = project((;), healthy_only; grid, initial=[HEALTHY => 1.0], history=true)
        for (k, t) in enumerate(grid)
            @test get(p.history[k], HEALTHY, 0.0) ≈ survival(single, t) atol = 1e-12
        end
        contract = ltc_contract(healthy_only; term, premium=1 / 12)
        valued = policy_values(contract, healthy_only, curve; grid, terminal=0, roots=[HEALTHY]).before[HEALTHY]
        @test -valued.premium ≈ present_value(AnnuityDue(single, curve, term; frequency=12))
        @test valued.care == 0
        single_death = policy_values((death=LifeContingencies.death_payment(single),), single, curve; grid, terminal=0, roots=[:alive])
        @test valued.death ≈ single_death.before[:alive].death
    end

    @testset "against enumeration over six months" begin
        grid = range(0, 0.5, length=7)
        contract = ltc_contract(m; term=1, premium=0.03)
        # healthy; partway through the elimination period; one benefit month from the maximum
        for start in (HEALTHY, LTCState(:claim, 2, false, 0), LTCState(:claim, 0, true, m.maximum_benefit_months - 1))
            valued = policy_values(contract, m, curve; grid, terminal=0, roots=[start]).before[start]
            for name in keys(contract)
                @test valued[name] ≈ enumerated_value(contract[name], m, grid, curve, start) atol = 1e-12
            end
        end
    end

    @testset "a second claim keeps its qualification and benefit count" begin
        path = [
            HEALTHY,
            LTCState(:claim, 0, false, 0),   # incidence
            LTCState(:claim, 1, false, 0),
            LTCState(:claim, 2, false, 0),
            LTCState(:claim, 3, true, 0),    # the elimination period is satisfied
            LTCState(:claim, 4, true, 1),    # the first benefit month is paid
            LTCState(:healthy, 0, true, 1),  # recovery keeps the qualification and the count
            LTCState(:claim, 0, true, 1),    # a second claim, with no new elimination period
            LTCState(:claim, 1, true, 2),
        ]
        grid = months(1)
        care = ltc_contract(m; term=1, premium=0.03).care
        payments = map(1:length(path)-1) do k
            interval = Interval(grid[k], grid[k+1])
            @test row_probabilities(m, interval, path[k])[path[k+1]] > 0
            care.f(interval, path[k], path[k+1])
        end
        @test payments == [0, 0, 0, 0, 1, 0.5, 0, 1]
        # a used-up benefit pays nothing more
        exhausted = LTCState(:claim, RATE_BANDS, true, m.maximum_benefit_months)
        @test care.f(Interval(grid[1], grid[2]), exhausted, exhausted) == 0
    end

    @testset "Monte Carlo agreement" begin
        term = 2
        grid = months(term)
        contract = ltc_contract(m; term, premium=0.03)
        valued = policy_values(contract, m, curve; grid, terminal=0, roots=[HEALTHY]).before[HEALTHY]
        rng = Random.Xoshiro(20261025)
        n = 20_000
        samples = [simulated_value(contract, m, curve, grid, HEALTHY, rng) for _ in 1:n]
        for name in keys(contract)
            xs = [sample[name] for sample in samples]
            mean = sum(xs) / n
            standard_error = sqrt(sum(x -> (x - mean)^2, xs) / (n - 1) / n)
            @test abs(mean - valued[name]) <= 4 * standard_error
        end
    end

    @testset "healthy and claim policy values" begin
        grid = months(10)
        unit = policy_values(ltc_contract(m; term=10, premium=1.0), m, curve; grid, terminal=0, roots=[HEALTHY]).before[HEALTHY]
        premium = (unit.care + unit.death) / -unit.premium
        contract = ltc_contract(m; term=10, premium)
        claims = [LTCState(:claim, 0, false, 0), LTCState(:claim, RATE_BANDS, true, 10)]
        valued = policy_values(contract, m, curve; grid, terminal=0, roots=[HEALTHY; claims])
        # the net premium balances at issue, and claims carry positive reserves
        @test sum(valued.before[HEALTHY]) ≈ 0 atol = 1e-12
        @test all(s -> sum(valued.before[s]) > 0, claims)
        # premiums are waived on claim, so a claim's premium value comes only after recovery
        @test valued.before[claims[1]].premium > valued.before[HEALTHY].premium
        p = project(contract, m; grid, initial=[HEALTHY => 1.0], history=true)
        @test all(occupancy -> sum(values(occupancy)) ≈ 1, p.history)
        # the model moves a month at a time
        @test_throws ArgumentError transitions(m, Interval(0.0, 1.0), HEALTHY)
    end
end
