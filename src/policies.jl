"""
    PricedPolicy(benefit, premiums; premium=nothing)

An immutable priced policy holding a benefit product, a premium annuity and its established
annualized premium. Products must share their issue mortality and interest basis. Omit
`premium` to price by equivalence once, or supply a finite premium for an existing policy.
Revaluation via [`policy_value`](@ref) retains this premium and contractual timing.
At frequency `f`, each premium installment is `premium/f`.
"""
struct PricedPolicy{B,A,T}
    benefit::B
    premiums::A
    premium::T
    function PricedPolicy(benefit::Insurance, premiums::Annuity; premium=nothing)
        check_common_basis(benefit, premiums)
        p = isnothing(premium) ? premium_net(benefit, premiums) : premium
        p isa Real && isfinite(p) || throw(ArgumentError("premium must be a finite real amount; got $p"))
        return new{typeof(benefit),typeof(premiums),typeof(p)}(benefit, premiums, p)
    end
end
Base.broadcastable(p::PricedPolicy) = Ref(p)

same_life(a::SingleLife, b::SingleLife) =
    same_origin(a, b) && isequal(a.mortality, b.mortality) && isequal(a.fractional_assump, b.fractional_assump)
same_life(a::JointLife, b::JointLife) =
    same_origin(a, b) && isequal(a.joint_assumption, b.joint_assumption) && all(same_life.(a.lives, b.lives))
same_life(a::Life, b::Life) = false
same_origin(a::SingleLife, b::SingleLife) = a.issue_age == b.issue_age && a.alive == b.alive
same_origin(a::JointLife, b::JointLife) =
    isequal(a.contingency, b.contingency) && all(same_origin.(a.lives, b.lives))
same_origin(a::Life, b::Life) = false

function check_common_basis(b, p)
    p.certain == 0 || throw(ArgumentError("premium annuities cannot guarantee premiums after death; use certain=0"))
    same_life(b.life, p.life) && isequal(b.int, p.int) ||
        throw(ArgumentError("benefits and premiums must share an issue mortality and interest basis"))
end

"""
    premium_net(benefit, premiums)

Price the benefit by equivalence against an annualized premium annuity on their common
basis. A zero premium-annuity PV is undefined. Access `policy.premium` for an established
premium, which may differ from this equivalence premium.
"""
function premium_net(benefit::Insurance, premiums::Annuity)
    check_common_basis(benefit, premiums)
    return equivalence_premium(present_value(benefit), present_value(premiums))
end
premium_net(life::Life, interest, args...) = premium_net(LifeContingency(life, interest), args...)

rebase(p::DeathBenefit, basis) = Insurance(basis, p.term)
rebase(p::Endowment, basis) = Endowment(basis, p.term)
rebase(p::Annuity, basis) = annuity(p.kind, basis.life, basis.int, p.term;
    certain=p.certain, start_time=p.start_time, frequency=p.frequency)

scale_component(c::StatePayment, a) = StatePayment((t, s) -> a * c.f(t, s))
scale_component(c::TransitionPayment, a) = TransitionPayment((i, s, d) -> a * c.f(i, s, d))
scale_component(c::CertainPayment, a) = CertainPayment(c.times, a .* c.amounts)

# Keep certain installments outside the state recursion. A suffix sweep values them in
# linear discount work, without rescanning every guarantee at every state and date.
function certain_tails!(result, component, curve, times, include_now)
    c = component
    order = sortperm(times; rev=true)
    k = length(c.times)
    tail = zero(eltype(result))
    anchor = nothing
    for i in order
        t = times[i]
        while k >= 1 && (c.times[k] > t || (include_now && c.times[k] == t))
            date = c.times[k]
            isnothing(anchor) || iszero(tail) || (tail *= discount(curve, date, anchor))
            tail += c.amounts[k]
            anchor = date
            k -= 1
        end
        # Interval factors avoid underflow/cancellation in ratios of issue-date PVs.
        iszero(tail) || (result[i] += tail * discount(curve, t, anchor))
    end
end

function prepare_product(product, coefficient, prefix)
    (; contract, grid) = unit_payments(product)
    scaled = map(values(contract)) do c
        if c isa TransitionPayment && product isa Union{DeathBenefit,Endowment}
            # Premium dates may refine an annual death interval. Carry the value of
            # the claim at its contractual year-end settlement back to this edge.
            last_year = product isa DeathBenefit ? benefit_years(product) : product.term
            return TransitionPayment() do i, from, to
                i.stop > last_year && return zero(coefficient)
                amount = coefficient * c.f(i, from, to)
                iszero(amount) && return amount
                return amount * discount(product.int, i.stop, ceil(i.stop))
            end
        end
        return scale_component(c, coefficient)
    end
    named = NamedTuple{Tuple(Symbol(prefix, "_", k) for k in keys(contract))}(scaled)
    contingent = (; (k => c for (k, c) in pairs(named) if !(c isa CertainPayment))...)
    certain = [c for c in values(named) if c isa CertainPayment]
    return (; contingent, certain, grid, due=is_due(product))
end

# One frontier per date, seeded at each requested known/conditioned status. Unlike seeding
# only at issue, this also values observed states with zero issue probability.
function seeded_frontiers(life, grid, seeds, index, ::Type{T}) where {T}
    positions, ranges, current = Int[], UnitRange{Int}[], Int[]
    for k in eachindex(grid)
        append!(current, get(seeds, k, Int[]))
        unique!(current)
        start = length(positions) + 1
        append!(positions, current)
        push!(ranges, start:length(positions))
        k == length(grid) && break
        next = Int[]
        interval = Experimental.Interval(grid[k], grid[k+1])
        for i in current
            state = index.states[i]
            Experimental.fold_row(nothing, Experimental.transitions(life, interval, state), state, interval, T) do _, dest, _
                push!(next, Experimental.position!(index, dest))
                nothing
            end
        end
        current = unique!(next)
    end
    return Experimental.Frontiers(positions, ranges)
end

function outstanding_dates(product)
    dates = timepoints(product)
    if product isa Annuity && !isempty(dates)
        s = schedule(product)
        # A zero contingent installment at established extinction is not an obligation.
        if s.guaranteed < length(dates) && last(dates) == s.horizon && iszero(survival(product.life, s.horizon))
            return dates[1:end-1]
        end
    end
    return dates
end

outstanding(dates, due, t, phase) =
    !isempty(dates) && (last(dates) > t || (due && phase === :before && insorted(t, dates)))

function policy_basis(policy, basis)
    basis = isnothing(basis) ? LifeContingency(policy.benefit) : basis
    basis isa LifeContingency || throw(ArgumentError("basis must be a LifeContingency"))
    same_origin(policy.benefit.life, basis.life) ||
        throw(ArgumentError("valuation basis must retain original age origins, starting statuses, life order and contingency"))
    return basis
end

# The common annual whole-life case needs neither a union grid nor stored histories.
# Keep it on the same backward engine kernel used before product composition.
classic_whole_life(p) = p.benefit isa DeathBenefit && isnothing(p.benefit.term) &&
    p.premiums.kind isa Due && isnothing(p.premiums.term) && p.premiums.frequency == 1 &&
    p.premiums.start_time == 0 && p.premiums.certain == 0

function whole_life_value(policy, time; basis=nothing, state=nothing, phase=:before)
    basis = policy_basis(policy, basis)
    life, premium = basis.life, policy.premium
    check_valuation(time, phase, life, state)
    T = promote_type(value_type(life, basis.int), typeof(premium))
    horizon = benefit_years(Insurance(basis))
    time >= horizon && return zero(T)
    initial = isnothing(state) ? in_force_distribution(life, time) : [state => one(T)]
    contract = (
        benefit=death_payment(life),
        premium=StatePayment((t, s) -> active(life, s) ? -premium : zero(premium)),
    )
    valued = policy_values(contract, life, basis.int; grid=time:horizon, terminal=0, roots=first.(initial), numbertype=T)
    values = phase === :before ? valued.before : valued.after
    return sum(q * sum(values[s]) for (s, q) in initial)
end

function policy_value_column(policy, times; basis=nothing, state=nothing, phase=:before)
    basis = policy_basis(policy, basis)
    for t in times
        t isa Integer || throw(ArgumentError("reserves require integer anniversaries; got $t"))
        check_valuation(t, phase, basis.life, state)
    end
    # Validate keywords even for an empty column.
    check_valuation(0, phase, basis.life, state)
    T = promote_type(value_type(basis.life, basis.int), typeof(policy.premium))
    result = zeros(T, length(times))
    isempty(times) && return result
    benefit_product, premium_product = rebase(policy.benefit, basis), rebase(policy.premiums, basis)
    b = prepare_product(benefit_product, benefit(benefit_product), :benefit)
    p = prepare_product(premium_product, -policy.premium * benefit(premium_product), :premium)
    for prepared in (b, p), c in prepared.certain
        certain_tails!(result, c, basis.int, times, prepared.due && phase === :before)
    end
    bdates, pdates = outstanding_dates(benefit_product), outstanding_dates(premium_product)
    live_queries = findall(i -> outstanding(bdates, b.due, times[i], phase) || outstanding(pdates, p.due, times[i], phase), eachindex(times))
    isempty(live_queries) && return result
    horizon = max(last(b.grid), last(p.grid))
    # Occupancy is needed for default conditioning even if only guarantees remain.
    occupancy_end = isnothing(state) ? max(horizon, maximum(times[live_queries])) : horizon
    grid = sort!(unique!([collect(b.grid); collect(p.grid); filter(t -> t <= occupancy_end, times[live_queries])]))
    weights = nothing
    # Request history once, rather than repeating issue-to-date projection per reserve.
    if isnothing(state)
        occupancy_grid = filter(t -> t <= maximum(times[live_queries]), grid)
        if length(live_queries) == 1
            final = project((;), basis.life; grid=occupancy_grid, initial=initial_distribution(basis.life), numbertype=T).final
            weights = Dict(length(occupancy_grid) => final)
        else
            weights = project((;), basis.life; grid=occupancy_grid, initial=initial_distribution(basis.life), history=true, numbertype=T).history
        end
    end
    distributions = Dict{Int,Vector{Pair{eltype(Experimental.states(basis.life)),T}}}()
    for i in live_queries
        t = times[i]
        if isnothing(state)
            k = searchsortedfirst(grid, t)
            distributions[i] = condition(weights[k], s -> active(basis.life, s))
        else
            distributions[i] = [state => one(T)]
        end
    end
    # Past contingent dates, only directly discounted guarantees remain.
    first_query = minimum(times[live_queries])
    grid = filter(t -> first_query <= t <= horizon, grid)
    index = Experimental.state_index(basis.life, eltype(Experimental.states(basis.life)))
    seeds = Dict{Int,Vector{Int}}()
    for i in live_queries
        times[i] > horizon && continue
        k = searchsortedfirst(grid, times[i])
        append!(get!(seeds, k, Int[]), [Experimental.position!(index, s) for (s, q) in distributions[i] if !iszero(q)])
    end
    isempty(seeds) && return result
    contract = merge(b.contingent, p.contingent)
    frontiers = seeded_frontiers(basis.life, grid, seeds, index, T)
    terminal = Experimental.terminal_functions(contract, 0)
    history = length(live_queries) > 1
    roots = history ? Int[] : collect(frontiers[1])
    valued = Experimental.value_frontiers(contract, basis.life, basis.int, grid, terminal, roots, index, frontiers, T, history)
    for i in live_queries
        times[i] > horizon && continue
        t = times[i]
        k = searchsortedfirst(grid, t)
        result[i] += sum(distributions[i]) do (s, q)
            iszero(q) && return zero(T)
            v = sum(history ? valued.history[k][s].before : valued.before[s])
            (b.due && phase === :before) || (v -= payment_now(b.contingent, t, s))
            (p.due && phase === :before) || (v -= payment_now(p.contingent, t, s))
            return q * v
        end
    end
    return result
end

"""
    policy_value(policy::PricedPolicy, time_or_times; basis=nothing, state=nothing, phase=:before)

Prospective benefit values less the policy's scheduled premiums at integer anniversaries.
A new `LifeContingency` `basis` changes valuation assumptions while retaining the stored
premium. This does not recompute a valuation net premium. A collection returns a numeric
vector in the supplied order, using one occupancy pass and one backward pass.

By default, condition on the contingency remaining active; `state` supplies a known status.
End-period benefits have settled; `phase=:before` includes due installments and `:after`
settles them too. With only an annual premium due, these are the terminal and initial
values respectively. Settled contracts have zero value; impossible conditioning before
termination raises `DomainError`. Expenses are not modeled by these unit products.
"""
policy_value(p::PricedPolicy, t::Integer; kwargs...) =
    classic_whole_life(p) ? whole_life_value(p, t; kwargs...) : only(policy_value_column(p, [t]; kwargs...))
policy_value(p::PricedPolicy, times::AbstractVector; kwargs...) = policy_value_column(p, collect(times); kwargs...)
policy_value(p::PricedPolicy, t::Real; kwargs...) = throw(ArgumentError("policy values require integer anniversaries; got $t"))

# Textbook NPR: establish the equivalence premium on the very basis being valued.
# Revaluation with a retained premium is deliberately available only via policy_value.
"""
    reserve_premium_net(lc::LifeContingency, time_or_times; state=nothing, phase=:before)
    reserve_premium_net(life, interest, time_or_times; state=nothing, phase=:before)

Textbook whole-life net premium reserves with annual premiums. Both the equivalence premium
and the future benefits are calculated on the supplied `lc` basis. Pass a nonnegative
integer anniversary or a vector/range of anniversaries; a collection returns values in
its supplied order. No alternative valuation basis or stored-premium policy is accepted.
Use [`policy_value`](@ref) with a [`PricedPolicy`](@ref) for established premiums, finite
contracts, limited-pay business or revaluation on another basis. These unit products do
not implement statutory or GAAP reserve methods.

Death benefits through the valuation anniversary have settled. `phase=:before` includes
the premium due then (terminal reserve); `phase=:after` settles it (initial reserve).
Default conditioning is on the contingency remaining active; `state` supplies a known
single or joint status. Impossible conditioning before contractual termination raises
`DomainError`; once all obligations have settled, the reserve is zero.
"""
reserve_premium_net(lc::LifeContingency, times; state=nothing, phase=:before) =
    policy_value(PricedPolicy(Insurance(lc), AnnuityDue(lc)), times; state, phase)
reserve_premium_net(life::Life, interest, times; state=nothing, phase=:before) =
    reserve_premium_net(LifeContingency(life, interest), times; state, phase)
