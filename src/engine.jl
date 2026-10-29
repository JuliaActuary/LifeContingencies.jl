"""
    LifeContingencies.Experimental

A finite-state engine for contingent payments: a model supplies one-step transition rows over
a time grid, a contract is a `NamedTuple` of payment components, and the engine projects
expected cash flows forward ([`project`](@ref)), values them from a starting distribution
([`present_values`](@ref)), or values them backward by state ([`policy_values`](@ref)).

These interfaces are experimental and may change in minor releases.
"""
module Experimental

using FinanceCore: Cashflow, discount

export Interval, transitions, states,
    StatePayment, TransitionPayment, CertainPayment,
    project, present_values, policy_values, condition

# Probabilities must be nonnegative. A row or distribution must sum to one up to rounding: at
# most this many units in the last place of each probability's type, per entry. Nothing is
# rescaled, so a row that passes moves mass only by rounding.
const ROUNDING_ULPS = 8
rounding_slack(p) = ROUNDING_ULPS * eps(float(typeof(p)))

"""
    Interval(start, stop)

One step of a time grid, from `start` to `stop` in curve time. Models receive it in
[`transitions`](@ref), and transition payments receive it in their amount function.
"""
struct Interval{T<:Real}
    start::T
    stop::T
end

"""
    transitions(model, interval::Interval, state)

The one-step row of `model` from `state` over `interval`: an iterable of
`next_state => probability` pairs. The engine reads each row once, so it may be an iterator
that can be read only once. Every state of a model must have the same type.

Probabilities must be nonnegative, and they must sum to one up to rounding: within eight
units in the last place of their type for each entry. The engine checks each row it uses and
throws an `ArgumentError` for one that fails; it never rescales a row. Compute a complement
such as `1 - p - q` with care, or clamp it at zero, since rounding can make it negative.

Define a method for each model type. It must be pure: the engine may call it more than once
with the same arguments. A model that supports only some intervals, such as whole months,
should throw an `ArgumentError` for the others.
"""
function transitions end

"""
    states(model)

Optional: every state of `model`. [`policy_values`](@ref) uses them as its default `roots`.

When they are a tuple, the engine also indexes states by their place in it, comparing states
rather than hashing them, which is faster for a model with a few states. A row that reaches a
state outside the tuple then throws an `ArgumentError`.
"""
function states end

"""
    StatePayment(f)

A payment at each grid time `t` to anyone in `state`, of amount `f(t, state)`.
"""
struct StatePayment{F}
    f::F
end

"""
    TransitionPayment(f)

A payment on each one-step transition `from → to` over `interval`, of amount
`f(interval, from, to)`, paid at `interval.stop`. Self-transitions (`from == to`) are
included, which is how accrual over a period is expressed.
"""
struct TransitionPayment{F}
    f::F
end

"""
    CertainPayment(times, amounts)

Payments of `amounts` at `times`, independent of state. They are valued directly by
discounting, so they need no occupancy and never take a `terminal` value.
"""
struct CertainPayment{T,A}
    times::T
    amounts::A
    function CertainPayment(times, amounts)
        length(times) == length(amounts) ||
            throw(ArgumentError("CertainPayment needs one amount per time; got $(length(times)) times and $(length(amounts)) amounts"))
        return new{typeof(times),typeof(amounts)}(times, amounts)
    end
end

const Component = Union{StatePayment,TransitionPayment,CertainPayment}

# The amount each component pays in each channel. `false` is Julia's strong zero: it adds
# and multiplies as zero without changing the other operand's type.
state_amount(c::StatePayment, t, state) = c.f(t, state)
state_amount(::Union{TransitionPayment,CertainPayment}, t, state) = false
transition_amount(c::TransitionPayment, interval, from, to) = c.f(interval, from, to)
transition_amount(::Union{StatePayment,CertainPayment}, interval, from, to) = false

function certain_value(c::CertainPayment, curve, t, ::Type{T}; include_now::Bool) where {T}
    return sum(zip(c.times, c.amounts); init=zero(T)) do (τ, amount)
        τ > t || (include_now && τ == t) ? amount * discount(curve, t, τ) : zero(T)
    end
end

"""
    Projection

The result of [`project`](@ref).

- `cashflows`: a `NamedTuple` with a vector of `FinanceCore.Cashflow`s for each component.
  State payments are dated at every grid time, transition payments at every grid time after
  the first, and certain payments at their own times from the first grid time on.
- `final`: occupancy at the last grid time, as a `Dict` of state to probability.
- `history`: occupancy at every grid time when requested, otherwise `nothing`.
"""
struct Projection{C,S,T}
    cashflows::C
    final::Dict{S,T}
    history::Union{Nothing,Vector{Dict{S,T}}}
end

"""
    PolicyValues

The result of [`policy_values`](@ref).

- `before`: for each root state, a `NamedTuple` of component values at the first grid time,
  before the payments scheduled then (V⁻).
- `after`: the same values after those payments (V⁺).
- `history`: when requested, one `Dict` per grid time from each reachable state to
  `(before = ..., after = ...)`; otherwise `nothing`.
"""
struct PolicyValues{S,V,H}
    before::Dict{S,V}
    after::Dict{S,V}
    history::H
end

# Integer positions for the states the engine has met so far.
struct StateIndex{S}
    position::Dict{S,Int}
    states::Vector{S}
end

StateIndex{S}() where {S} = StateIndex{S}(Dict{S,Int}(), S[])

function position!(index::StateIndex, state)
    i = get(index.position, state, 0)
    if i == 0
        push!(index.states, state)
        i = index.position[state] = length(index.states)
    end
    return i
end

# Positions for a model that lists its states in a tuple: each state's place in the tuple,
# found by comparison rather than by hashing.
struct ListedIndex{S,N}
    states::NTuple{N,S}
end

function position!(index::ListedIndex, state)
    i = findfirst(isequal(state), index.states)
    isnothing(i) && throw(ArgumentError("$state is not one of the model's states $(index.states)"))
    return i
end

state_index(model, ::Type{S}) where {S} = index_for(listed_states(model), S)
index_for(listed::Tuple, ::Type) = ListedIndex(listed)
index_for(::Any, ::Type{S}) where {S} = StateIndex{S}()
listed_states(model) = hasmethod(states, Tuple{typeof(model)}) ? states(model) : nothing

function grow!(v::Vector, n)
    while length(v) < n
        push!(v, zero(eltype(v)))
    end
    return v
end

# Probability mass by state position. `positions` lists the positions given mass since the
# last `clear!`, so a step costs time in the states it touches rather than in every state
# met so far.
struct Occupancy{T}
    mass::Vector{T}
    listed::Vector{Bool}
    positions::Vector{Int}
end

Occupancy{T}() where {T} = Occupancy{T}(T[], Bool[], Int[])

function add!(o::Occupancy, i, p)
    grow!(o.mass, i)
    grow!(o.listed, i)
    if !o.listed[i]
        o.listed[i] = true
        push!(o.positions, i)
    end
    o.mass[i] += p
    return nothing
end

function clear!(o::Occupancy)
    for i in o.positions
        o.mass[i] = zero(eltype(o.mass))
        o.listed[i] = false
    end
    empty!(o.positions)
    return nothing
end

snapshot(index, o::Occupancy) =
    Dict(index.states[i] => o.mass[i] for i in o.positions if !iszero(o.mass[i]))

distribution_pairs(d::AbstractDict) = collect(d)
distribution_pairs(d::AbstractVector{<:Pair}) = d
distribution_pairs(d) =
    throw(ArgumentError("a distribution is a collection of `state => probability` pairs, such as `[state => 1.0]`; got $(typeof(d))"))

function check_distribution(pairs)
    isempty(pairs) && throw(ArgumentError("the initial distribution is empty"))
    for (state, p) in pairs
        p < 0 && throw(ArgumentError("negative initial probability $p for state $state"))
    end
    total = sum(last, pairs)
    abs(total - 1) <= sum(rounding_slack ∘ last, pairs) || throw(ArgumentError("initial probabilities sum to $total, not 1"))
    return nothing
end

function check_grid(grid)
    isempty(grid) && throw(ArgumentError("the grid is empty"))
    for k in firstindex(grid):lastindex(grid)-1
        grid[k] < grid[k+1] || throw(ArgumentError("grid times must increase strictly; got $(grid[k]) then $(grid[k+1])"))
    end
    return nothing
end

function check_contract(contract::NamedTuple)
    for (name, c) in pairs(contract)
        c isa Component ||
            throw(ArgumentError("contract component `$name` is a $(typeof(c)); use StatePayment, TransitionPayment or CertainPayment"))
    end
    return nothing
end

# Read `row` once, checking it as it goes, and fold `f(acc, next_state, q)` over its edges
# with nonzero probability.
function fold_row(f, acc, row, state, interval, ::Type{T}) where {T}
    total, slack = zero(T), zero(T)
    for (next_state, q) in row
        q < 0 && throw(ArgumentError("negative probability $q for $state → $next_state over $interval"))
        total += q
        slack += rounding_slack(q)
        iszero(q) || (acc = f(acc, next_state, q))
    end
    abs(total - 1) <= slack || throw(ArgumentError("transition probabilities from $state over $interval sum to $total, not 1"))
    return acc
end

needs_occupancy(contract) = any(c -> !(c isa CertainPayment), values(contract))

"""
    project(contract, model; grid, initial, history=false, numbertype=Float64)

Project `contract`'s expected cash flows over `grid`, starting from the distribution
`initial` (`state => probability` pairs; use `[state => 1.0]` for a known state) at
`grid[1]`. Returns a [`Projection`](@ref).

Reachable states are discovered from `initial` by following [`transitions`](@ref). Each row
is validated as it is used. `numbertype` is the number type for occupancy and amounts, for
example `BigFloat` or a dual-number type.
"""
function project(contract::NamedTuple, model; grid, initial, history::Bool=false, numbertype::Type=Float64)
    check_contract(contract)
    check_grid(grid)
    start = distribution_pairs(initial)
    check_distribution(start)
    S = mapreduce(typeof ∘ first, typejoin, start)
    # the state and number types are only known here, so specialize the work on them
    return project_states(contract, model, grid, start, state_index(model, S), numbertype, history)
end

function project_states(contract, model, grid, start, index, ::Type{T}, history) where {T}
    S = eltype(index.states)
    n = length(grid)
    amounts = map(_ -> Vector{T}(undef, n), contract)
    occupancy = history ? Vector{Dict{S,T}}(undef, n) : nothing
    _, final = forward(nothing, contract, model, grid, start, index, T) do _, k, due, current
        map((a, d) -> (a[k] = d; nothing), amounts, due)
        isnothing(occupancy) || (occupancy[k] = snapshot(index, current))
        return nothing
    end
    cashflows = map((c, a) -> component_cashflows(c, a, grid), contract, amounts)
    return Projection(cashflows, snapshot(index, final), occupancy)
end

# The forward recursion behind `project` and `present_values`. At each grid time it calls
# `step(acc, k, due, occupancy)`, where `due` holds each component's payments at `grid[k]`:
# state payments for the occupancy then, and transition payments for the interval ending
# then. It returns the last `acc` and the occupancy at the last grid time.
function forward(step, acc, contract, model, grid, start, index, ::Type{T}) where {T}
    current, next = Occupancy{T}(), Occupancy{T}()
    for (state, p) in start
        add!(current, position!(index, state), p)
    end
    nothing_due = map(_ -> zero(T), contract)
    n = length(grid)
    due = nothing_due
    for k in 1:n
        t = grid[k]
        for i in current.positions
            p = current.mass[i]
            iszero(p) && continue
            due = add_state_amounts(due, contract, p, t, index.states[i])
        end
        acc = step(acc, k, due, current)
        k == n && break
        due = advance!(next, current, contract, model, Interval(t, grid[k+1]), index, nothing_due, T)
        clear!(current)
        current, next = next, current
    end
    return acc, current
end

# Move the mass in `current` over `interval` into `next`, adding the transition payments for
# the interval to `due`.
function advance!(next, current, contract, model, interval, index, due, ::Type{T}) where {T}
    for i in current.positions
        p = current.mass[i]
        iszero(p) && continue
        state = index.states[i]
        due = fold_row(due, transitions(model, interval, state), state, interval, T) do due, next_state, q
            add!(next, position!(index, next_state), p * q)
            add_transition_amounts(due, contract, p * q, interval, state, next_state)
        end
    end
    return due
end

add_state_amounts(due, contract, p, t, state) =
    map((d, c) -> d + p * state_amount(c, t, state), due, contract)
add_transition_amounts(due, contract, pq, interval, from, to) =
    map((d, c) -> d + pq * transition_amount(c, interval, from, to), due, contract)

component_cashflows(::StatePayment, amounts, grid) = [Cashflow(amounts[k], grid[k]) for k in eachindex(grid)]
component_cashflows(::TransitionPayment, amounts, grid) = [Cashflow(amounts[k], grid[k]) for k in eachindex(grid)[2:end]]
component_cashflows(c::CertainPayment, amounts, grid) =
    [Cashflow(amount, τ) for (τ, amount) in zip(c.times, c.amounts) if τ >= first(grid)]

"""
    present_values(contract, model, curve; grid, initial, numbertype=Float64)

The expected present value at `grid[1]` of each of `contract`'s components, starting from the
distribution `initial` (`state => probability` pairs) at `grid[1]`. Returns a `NamedTuple`
keyed by component name.

The values include the payments scheduled at `grid[1]`, so they equal `Σᵢ πᵢ V⁻ᵢ` from
[`policy_values`](@ref) with `terminal = 0`. They are discounted with
`discount(curve, grid[1], t)`, and certain components are valued directly, as in
`policy_values`. One forward pass computes them without storing cash flows or values by
state. `numbertype` is the number type for occupancy and values.
"""
function present_values(contract::NamedTuple, model, curve; grid, initial, numbertype::Type=Float64)
    check_contract(contract)
    check_grid(grid)
    start = distribution_pairs(initial)
    check_distribution(start)
    S = mapreduce(typeof ∘ first, typejoin, start)
    # the state and number types are only known here, so specialize the work on them
    return discount_states(contract, model, curve, grid, start, state_index(model, S), numbertype)
end

function discount_states(contract, model, curve, grid, start, index, ::Type{T}) where {T}
    t₀ = first(grid)
    values = map(_ -> zero(T), contract)
    if needs_occupancy(contract)
        values, _ = forward(values, contract, model, grid, start, index, T) do acc, k, due, _
            d = discount(curve, t₀, grid[k])
            map((v, x) -> v + d * x, acc, due)
        end
    end
    return map((c, v) -> component_before(c, v, curve, t₀, T), contract, values)
end

"""
    policy_values(contract, model, curve; grid, terminal, roots=states(model), history=false, numbertype=Float64)

Value `contract` by state at `grid[1]`, discounting on `curve` with interval factors
`discount(curve, tₖ, tₖ₊₁)`. Returns a [`PolicyValues`](@ref) for each state in `roots`.

Payment phases:
- Transition payments for the interval ending at `t` are settled at `t`.
- `b(t)` is every payment scheduled at `t`: state payments for the occupied state, plus
  certain payments.
- `V⁻(t)` is the value before `b(t)`, and `V⁺(t) = V⁻(t) - b(t)`.
- State and transition components follow
  `V⁻ₖ(i) = bₖ(i) + v(tₖ, tₖ₊₁) Σⱼ Pₖ(i,j) (rₖ(i,j) + V⁻ₖ₊₁(j))`, with
  `V⁻ₙ(i) = bₙ(i) + terminal(i)` at the final grid date. Here `tₖ = grid[k]`,
  `v(s,t) = discount(curve, s, t)`, and `rₖ(i,j)` is the transition payment.
  State components have `rₖ = 0`; transition components have `bₖ = 0`.
- Certain components are valued directly at every date: `Σ_{τ ≥ t} v(t,τ) aτ` before the
  payments at `t` and `Σ_{τ > t}` after. They are the same in every state.

`terminal` supplies `V⁺` at the last grid time for each state or transition component: a
`NamedTuple` of functions of the state, keyed by component name. `terminal = 0` sets every
one to zero. Certain components never take a terminal value. A terminal value of zero is
justified only by maturity, termination, or a deliberate truncation.

`roots` defaults to `states(model)` and must be passed when `states` isn't defined for
`model`. With `history = true`, values are also kept for every state reachable from the
roots at every grid time.
"""
function policy_values(contract::NamedTuple, model, curve; grid, terminal, roots=nothing, history::Bool=false, numbertype::Type=Float64)
    check_contract(contract)
    check_grid(grid)
    terminal_values = terminal_functions(contract, terminal)
    roots = collect(resolve_roots(model, roots))
    isempty(roots) && throw(ArgumentError("`roots` is empty"))
    S = mapreduce(typeof, typejoin, roots)
    # the state and number types are only known here, so specialize the work on them
    return value_states(contract, model, curve, grid, terminal_values, roots, state_index(model, S), numbertype, history)
end

function value_states(contract, model, curve, grid, terminal_values, roots, index, ::Type{T}, history) where {T}
    root_positions = unique!([position!(index, state) for state in roots])
    n = length(grid)
    frontiers = needs_occupancy(contract) ? reachable_frontiers(model, grid, index, root_positions, T) :
                Frontiers(root_positions, fill(1:length(root_positions), n))
    V_next = map(_ -> zeros(T, length(index.states)), contract)
    V_current = map(_ -> zeros(T, length(index.states)), contract)
    records = history ? Vector{Any}(undef, n) : nothing
    t = grid[n]
    for i in frontiers[n]
        state = index.states[i]
        map((c, v, f) -> (v[i] = state_amount(c, t, state) + terminal_value(f, state); nothing), contract, V_next, terminal_values)
    end
    history && (records[n] = values_at(contract, V_next, frontiers[n], index, curve, t, T))
    if needs_occupancy(contract)
        for k in n-1:-1:1
            interval = Interval(grid[k], grid[k+1])
            d = discount(curve, grid[k], grid[k+1])
            for i in frontiers[k]
                state = index.states[i]
                acc = expected_next(contract, model, V_next, interval, state, index, T)
                store_values!(V_current, acc, contract, i, grid[k], state, d)
            end
            history && (records[k] = values_at(contract, V_current, frontiers[k], index, curve, grid[k], T))
            V_current, V_next = V_next, V_current
        end
    elseif history
        for k in 1:n-1
            records[k] = values_at(contract, V_next, frontiers[k], index, curve, grid[k], T)
        end
    end
    at_start = values_at(contract, V_next, root_positions, index, curve, first(grid), T)
    before = Dict(state => v.before for (state, v) in at_start)
    after = Dict(state => v.after for (state, v) in at_start)
    return PolicyValues(before, after, isnothing(records) ? nothing : [r for r in records])
end

# Each component's expected transition payment and next value, one step on from `state`.
expected_next(contract, model, V, interval, state, index, ::Type{T}) where {T} =
    fold_row(map(_ -> zero(T), contract), transitions(model, interval, state), state, interval, T) do acc, next_state, q
        j = position!(index, next_state)
        map((a, c, v) -> a + q * (transition_amount(c, interval, state, next_state) + v[j]), acc, contract, V)
    end

function store_values!(V, acc, contract, i, t, state, d)
    map((v, a, c) -> (v[i] = state_amount(c, t, state) + d * a; nothing), V, acc, contract)
    return nothing
end

const CONTRACT_SHAPE = "a contract is a NamedTuple of StatePayment, TransitionPayment and CertainPayment components; the empty contract is (;)"

project(contract, model; kwargs...) = throw(ArgumentError(CONTRACT_SHAPE * "; got $(typeof(contract))"))
policy_values(contract, model, curve; kwargs...) = throw(ArgumentError(CONTRACT_SHAPE * "; got $(typeof(contract))"))

function resolve_roots(model, ::Nothing)
    hasmethod(states, Tuple{typeof(model)}) ||
        throw(ArgumentError("pass `roots`, or define `states(::$(typeof(model)))`"))
    return states(model)
end
resolve_roots(model, roots) = roots

function terminal_functions(contract, terminal::Number)
    iszero(terminal) ||
        throw(ArgumentError("`terminal` must be 0 or a NamedTuple of functions of the state, one for each state or transition component"))
    return map(c -> c isa CertainPayment ? nothing : zero_terminal, contract)
end

function terminal_functions(contract, terminal::NamedTuple)
    for name in keys(terminal)
        haskey(contract, name) || throw(ArgumentError("`terminal` names `$name`, which is not a contract component"))
        contract[name] isa CertainPayment &&
            throw(ArgumentError("`terminal` names `$name`, a CertainPayment; certain payments are valued directly and take no terminal value"))
    end
    functions = map(keys(contract), values(contract)) do name, c
        c isa CertainPayment && return nothing
        haskey(terminal, name) || throw(ArgumentError("`terminal` has no value for component `$name`"))
        return terminal[name]
    end
    return NamedTuple{keys(contract)}(functions)
end

terminal_functions(contract, terminal) =
    throw(ArgumentError("`terminal` must be 0 or a NamedTuple of functions of the state; got $(typeof(terminal))"))

zero_terminal(state) = false
terminal_value(::Nothing, state) = false
terminal_value(f, state) = f(state)

# The positions reachable at each grid time, stored back to back: those at grid time `k` are
# `positions[ranges[k]]`.
struct Frontiers
    positions::Vector{Int}
    ranges::Vector{UnitRange{Int}}
end

Base.getindex(f::Frontiers, k) = view(f.positions, f.ranges[k])

function reachable_frontiers(model, grid, index, roots, ::Type{T}) where {T}
    positions = copy(roots)
    ranges = [1:length(roots)]
    marked = Int[]
    for k in 1:length(grid)-1
        interval = Interval(grid[k], grid[k+1])
        found = length(positions)
        for r in ranges[k]
            state = index.states[positions[r]]
            fold_row(nothing, transitions(model, interval, state), state, interval, T) do _, next_state, _
                j = position!(index, next_state)
                grow!(marked, j)
                if marked[j] != k + 1
                    marked[j] = k + 1
                    push!(positions, j)
                end
                return nothing
            end
        end
        push!(ranges, found+1:length(positions))
    end
    return Frontiers(positions, ranges)
end

function values_at(contract, V, positions, index, curve, t, ::Type{T}) where {T}
    return Dict(map(positions) do i
        state = index.states[i]
        before = map((c, v) -> component_before(c, v[i], curve, t, T), contract, V)
        after = map((c, b) -> component_after(c, b, t, state, curve, T), contract, before)
        state => (before=before, after=after)
    end)
end

component_before(::Union{StatePayment,TransitionPayment}, v, curve, t, T) = v
component_before(c::CertainPayment, v, curve, t, T) = certain_value(c, curve, t, T; include_now=true)
component_after(c::StatePayment, before, t, state, curve, T) = before - c.f(t, state)
component_after(::TransitionPayment, before, t, state, curve, T) = before
component_after(c::CertainPayment, before, t, state, curve, T) = certain_value(c, curve, t, T; include_now=false)

"""
    condition(distribution, event)

Restrict `distribution` (`state => probability` pairs) to the states where `event(state)` is
true, and renormalize. Throws a `DomainError` when the event has probability zero.
"""
function condition(distribution, event)
    kept = [state => p for (state, p) in distribution_pairs(distribution) if event(state)]
    total = sum(last, kept; init=0)
    iszero(total) && throw(DomainError(total, "cannot condition on an event of probability zero"))
    return [state => p / total for (state, p) in kept]
end

end # module Experimental
