using LifeContingencies.Experimental
const Engine = LifeContingencies.Experimental

# Alive/dead with a mortality rate per unit step, indexed by the interval's start.
struct TwoState
    q::Vector{Float64}
end
function Engine.transitions(m::TwoState, interval::Interval, state::Symbol)
    q = m.q[Int(interval.start)+1]
    return state === :alive ? (:alive => 1 - q, :dead => q) : (:dead => 1.0, :dead => 0.0)
end
Engine.states(::TwoState) = (:alive, :dead)

# Healthy, sick (with recovery) and dead, with the same row every step.
struct HealthySick end
function Engine.transitions(::HealthySick, ::Interval, state::Symbol)
    state === :healthy && return (:healthy => 0.85, :sick => 0.10, :dead => 0.05)
    state === :sick && return (:healthy => 0.30, :sick => 0.55, :dead => 0.15)
    return (:dead => 1.0, :dead => 0.0, :dead => 0.0)
end
Engine.states(::HealthySick) = (:healthy, :sick, :dead)

# Everyone stays where they are. Defines no `states`.
struct Stay end
Engine.transitions(::Stay, ::Interval, state) = (state => 1.0,)

struct BadRowSum end
Engine.transitions(::BadRowSum, ::Interval, state) = (state => 0.9,)
struct NegativeRow end
Engine.transitions(::NegativeRow, ::Interval, state) = (state => 1.5, :elsewhere => -0.5)

# Counts the edges the engine is handed.
struct Counted{M}
    model::M
    edges::Base.RefValue{Int}
end
function Engine.transitions(m::Counted, interval::Interval, state)
    row = Engine.transitions(m.model, interval, state)
    m.edges[] += length(row)
    return row
end

# Two states, with every row split into K equal copies of each edge.
struct Repeated{K} end
function Engine.transitions(::Repeated{K}, ::Interval, state::Symbol) where {K}
    state === :alive && return (ntuple(_ -> :alive => 0.99 / K, Val(K))..., ntuple(_ -> :dead => 0.01 / K, Val(K))...)
    return (ntuple(_ -> :dead => 1.0 / K, Val(K))..., ntuple(_ -> :dead => 0.0, Val(K))...)
end

struct QuadraticCurve end
FinanceCore.discount(::QuadraticCurve, t) = exp(-0.01t^2)
FinanceCore.discount(c::QuadraticCurve, from, to) = discount(c, to) / discount(c, from)

# Brute-force oracle: list every path with its probability and add up its discounted payments.
# It shares no code with the engine's recursion.
function enumerate_paths(model, grid, state)
    paths = [([state], 1.0)]
    for k in 1:length(grid)-1
        interval = Interval(grid[k], grid[k+1])
        paths = [(vcat(path, next), p * q) for (path, p) in paths for (next, q) in transitions(model, interval, last(path))]
    end
    return paths
end

function path_value(c::StatePayment, path, grid, curve)
    return sum(c.f(grid[k], path[k]) * discount(curve, grid[1], grid[k]) for k in eachindex(grid))
end
function path_value(c::TransitionPayment, path, grid, curve)
    return sum(c.f(Interval(grid[k], grid[k+1]), path[k], path[k+1]) * discount(curve, grid[1], grid[k+1]) for k in 1:length(grid)-1)
end
enumerated_value(c, model, grid, curve, state) =
    sum(p * path_value(c, path, grid, curve) for (path, p) in enumerate_paths(model, grid, state))

# Present value at `t` of projected cash flows dated at or after `t` (`include_now`) or strictly after it.
tail_value(cashflows, curve, t; include_now) =
    sum((cf.amount * discount(curve, t, cf.time) for cf in cashflows if cf.time > t || (include_now && cf.time == t)); init=0.0)

const alive_annuity = StatePayment((t, s) -> s === :alive ? 1.0 : 0.0)
const death_benefit = TransitionPayment((interval, from, to) -> from === :alive && to === :dead ? 1.0 : 0.0)

const care = (
    premium=StatePayment((t, s) -> s === :healthy ? -0.3 : 0.0),
    sick_benefit=StatePayment((t, s) -> s === :sick ? 1.0 : 0.0),
    death=TransitionPayment((interval, from, to) -> from !== :dead && to === :dead ? 2.0 : 0.0),
    accrual=TransitionPayment((interval, from, to) -> from === :sick && to === :sick ? 0.5 : 0.0),
    guaranteed=CertainPayment([0.0, 1.0], [1.0, 1.0]),
)

@testset "engine" begin
    @testset "two states, by hand" begin
        m = TwoState([0.1, 0.2, 0.3])
        contract = (annuity=alive_annuity, death=death_benefit)
        p = project(contract, m; grid=0:3, initial=[:alive => 1.0], history=true)
        @test [cf.amount for cf in p.cashflows.annuity] ≈ [1.0, 0.9, 0.72, 0.504]
        @test [cf.time for cf in p.cashflows.annuity] == 0:3
        @test [cf.amount for cf in p.cashflows.death] ≈ [0.1, 0.18, 0.216]
        @test [cf.time for cf in p.cashflows.death] == 1:3
        @test p.final[:alive] ≈ 0.504 && p.final[:dead] ≈ 0.496

        v = 1 / 1.05
        valued = policy_values(contract, m, 0.05; grid=0:3, terminal=0)
        @test valued.before[:alive].annuity ≈ 1 + 0.9v + 0.72v^2 + 0.504v^3
        @test valued.after[:alive].annuity ≈ 0.9v + 0.72v^2 + 0.504v^3
        @test valued.before[:alive].death ≈ 0.1v + 0.18v^2 + 0.216v^3
        @test valued.after[:alive].death == valued.before[:alive].death
        @test valued.before[:dead] == (annuity=0.0, death=0.0)
    end

    @testset "three states with recovery, against enumeration" begin
        m = HealthySick()
        grid = 0:5
        for curve in (0.04, QuadraticCurve()), root in (:healthy, :sick, :dead)
            valued = policy_values(care, m, curve; grid, terminal=0)
            for name in (:premium, :sick_benefit, :death, :accrual)
                @test valued.before[root][name] ≈ enumerated_value(care[name], m, grid, curve, root) atol = 1e-12
            end
            @test valued.before[root].guaranteed ≈ 1 + discount(curve, 0, 1)
        end
    end

    @testset "laws" begin
        m = HealthySick()
        grid = 0:5
        curve = QuadraticCurve()
        initial = [:healthy => 0.6, :sick => 0.4]
        p = project(care, m; grid, initial, history=true)
        valued = policy_values(care, m, curve; grid, terminal=0, history=true)

        # conservation
        @test all(occupancy -> sum(values(occupancy)) ≈ 1, p.history)

        # linearity in the starting distribution, and forward/backward agreement at the start
        for name in keys(care)
            mixed = 0.6 * valued.before[:healthy][name] + 0.4 * valued.before[:sick][name]
            @test tail_value(p.cashflows[name], curve, 0; include_now=true) ≈ mixed
        end

        # forward/backward agreement at every grid time
        # (V⁻ includes payments at the valuation date; transition payments dated then are already settled)
        for k in eachindex(grid), name in keys(care)
            backward = sum(prob * valued.history[k][state].before[name] for (state, prob) in p.history[k])
            forward = tail_value(p.cashflows[name], curve, grid[k]; include_now=!(care[name] isa TransitionPayment))
            @test backward ≈ forward atol = 1e-12
        end

        # components add
        separate = map(keys(care)) do name
            policy_values(NamedTuple{(name,)}((care[name],)), m, curve; grid, terminal=0).before[:healthy][name]
        end
        @test sum(separate) ≈ sum(valued.before[:healthy])

        # the empty contract
        blank = project((;), m; grid, initial)
        @test blank.cashflows == (;)
        @test sum(values(blank.final)) ≈ 1
        @test policy_values((;), m, curve; grid, terminal=0).before[:healthy] == (;)

        # interval discount factors compose to the curve's own factor
        final_payment = (final=StatePayment((t, s) -> t == 3 ? 1.0 : 0.0),)
        @test policy_values(final_payment, Stay(), curve; grid=0:3, terminal=0, roots=[:here]).before[:here].final ≈
              discount(curve, 0, 3)
    end

    @testset "payment phases" begin
        m = HealthySick()
        grid = 0:5
        curve = 0.04
        valued = policy_values(care, m, curve; grid, terminal=0, history=true)
        at(k, state) = valued.history[k][state]

        # a premium, a sick benefit and a death benefit all fall at t = 2
        @test at(3, :healthy).after.premium ≈ at(3, :healthy).before.premium + 0.3
        @test at(3, :sick).after.sick_benefit ≈ at(3, :sick).before.sick_benefit - 1.0
        @test at(3, :healthy).after.death == at(3, :healthy).before.death
        # the death benefit for (1, 2] is settled at t = 2, so it belongs to V⁻ at t = 1
        row = Dict(transitions(m, Interval(1, 2), :healthy))
        expected = discount(curve, 1, 2) * sum(q * ((s === :dead ? 2.0 : 0.0) + at(3, s).before.death) for (s, q) in row)
        @test at(2, :healthy).before.death ≈ expected

        # a guaranteed installment at the valuation date is in V⁻ and not in V⁺
        @test at(1, :healthy).before.guaranteed ≈ 1 + discount(curve, 0, 1)
        @test at(1, :healthy).after.guaranteed ≈ discount(curve, 0, 1)
        @test at(2, :dead).before.guaranteed ≈ 1.0
        @test at(2, :dead).after.guaranteed == 0.0

        # self-transitions carry payments
        p = project(care, m; grid, initial=[:healthy => 1.0])
        @test p.cashflows.accrual[1].amount == 0.0
        @test p.cashflows.accrual[2].amount ≈ 0.10 * 0.55 * 0.5

        # terminal values are attributed to their own component and counted once
        two = (a=StatePayment((t, s) -> 1.0), b=StatePayment((t, s) -> 1.0))
        truncated = policy_values(two, Stay(), 0.0; grid=0:2, terminal=(a=s -> 10.0, b=s -> 0.0), roots=[:here])
        @test truncated.before[:here] == (a=13.0, b=3.0)
        @test truncated.after[:here] == (a=12.0, b=2.0)
    end

    @testset "validation" begin
        m = TwoState([0.1, 0.2, 0.3])
        @test_throws ArgumentError project((annuity=(t, s) -> 1.0,), m; grid=0:3, initial=[:alive => 1.0])
        @test_throws ArgumentError project((), m; grid=0:3, initial=[:alive => 1.0])
        @test_throws ArgumentError policy_values((), m, 0.0; grid=0:3, terminal=0)
        @test_throws ArgumentError project((annuity=alive_annuity,), m; grid=0:3, initial=:alive)
        @test_throws ArgumentError project((annuity=alive_annuity,), m; grid=0:3, initial=[:alive => 0.5])
        @test_throws ArgumentError project((annuity=alive_annuity,), m; grid=[0, 2, 1], initial=[:alive => 1.0])
        @test_throws ArgumentError project((annuity=alive_annuity,), m; grid=Int[], initial=[:alive => 1.0])
        @test_throws ArgumentError project((annuity=alive_annuity,), BadRowSum(); grid=0:1, initial=[:x => 1.0])
        @test_throws ArgumentError project((annuity=alive_annuity,), NegativeRow(); grid=0:1, initial=[:x => 1.0])
        @test_throws ArgumentError policy_values((annuity=alive_annuity,), BadRowSum(), 0.0; grid=0:1, terminal=0, roots=[:x])
        @test_throws ArgumentError CertainPayment([0, 1], [1.0])

        # roots come from `states(model)` or must be given
        @test_throws ArgumentError policy_values((annuity=alive_annuity,), Stay(), 0.0; grid=0:1, terminal=0)
        @test policy_values((annuity=alive_annuity,), Stay(), 0.0; grid=0:1, terminal=0, roots=[:alive]).before[:alive].annuity ≈ 2.0

        # terminal values
        contract = (annuity=alive_annuity, guaranteed=CertainPayment([0], [1.0]))
        @test_throws ArgumentError policy_values(contract, m, 0.0; grid=0:3, terminal=1)
        @test_throws ArgumentError policy_values(contract, m, 0.0; grid=0:3, terminal=(;))
        @test_throws ArgumentError policy_values(contract, m, 0.0; grid=0:3, terminal=(annuity=s -> 0.0, guaranteed=s -> 0.0))
        @test_throws ArgumentError policy_values(contract, m, 0.0; grid=0:3, terminal=(annuity=s -> 0.0, other=s -> 0.0))
        @test policy_values(contract, m, 0.0; grid=0:3, terminal=(annuity=s -> 0.0,)).before[:alive].guaranteed == 1.0

        # certain payments need no occupancy, so an invalid model is never consulted
        @test policy_values((guaranteed=CertainPayment([0, 1], [1.0, 1.0]),), BadRowSum(), 0.0; grid=0:1, terminal=0, roots=[:x]).before[:x].guaranteed == 2.0
    end

    @testset "condition" begin
        conditioned = condition([:healthy => 0.5, :sick => 0.25, :dead => 0.25], !=(:dead))
        @test first.(conditioned) == [:healthy, :sick]
        @test last.(conditioned) ≈ [2 / 3, 1 / 3]
        @test_throws DomainError condition([:dead => 1.0], !=(:dead))
    end

    @testset "number types" begin
        m = TwoState([0.1, 0.2, 0.3])
        contract = (annuity=alive_annuity, death=death_benefit)
        p = project(contract, m; grid=0:3, initial=[:alive => big(1)], numbertype=BigFloat)
        @test p.cashflows.annuity[end].amount isa BigFloat
        valued = policy_values(contract, m, 0.05; grid=0:3, terminal=0, numbertype=BigFloat)
        @test valued.before[:alive].annuity isa BigFloat
        @test valued.before[:alive].annuity ≈ policy_values(contract, m, 0.05; grid=0:3, terminal=0).before[:alive].annuity
    end

    @testset "work and allocation" begin
        steps = 40
        counted = Counted(TwoState(fill(0.01, steps)), Ref(0))
        project((annuity=alive_annuity,), counted; grid=0:steps, initial=[:alive => 1.0])
        # the first step expands only :alive (2 edges); every later step expands both states (2 + 2)
        @test counted.edges[] == 2 + 4 * (steps - 1)
        counted.edges[] = 0
        policy_values((annuity=alive_annuity,), counted, 0.0; grid=0:steps, terminal=0, roots=[:alive])
        # once to find the reachable states and once to value them
        @test counted.edges[] == 2 * (2 + 4 * (steps - 1))

        # splitting every edge eight ways adds work but no allocation
        contract = (annuity=alive_annuity, death=death_benefit)
        projecting(model) = @allocated project(contract, model; grid=0:steps, initial=[:alive => 1.0])
        valuing(model) = @allocated policy_values(contract, model, 0.05; grid=0:steps, terminal=0, roots=[:alive])
        for measure in (projecting, valuing)
            measure(Repeated{1}()), measure(Repeated{8}())
            @test measure(Repeated{8}()) == measure(Repeated{1}())
        end
    end
end
