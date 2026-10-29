# Stable life models have only two or four states. Keep distributions, rows and rolling
# values as tuples; cache rows and reachable-state masks, not dictionaries or value histories.
state_bit(i) = UInt8(1) << (i - 1)
has_state(mask, i) = !iszero(mask & state_bit(i))
function mass_mask(mass::NTuple{N}) where {N}
    mask = UInt8(0)
    for i in 1:N
        iszero(mass[i]) || (mask |= state_bit(i))
    end
    return mask
end

starting_state(life::SingleLife) = life.alive ? :alive : :dead
starting_state(life::JointLife) = map(starting_state, life.lives)
state_mass(i, ::Val{N}, ::Type{T}) where {N,T} = ntuple(j -> j == i ? one(T) : zero(T), Val(N))

function fixed_row(life, interval, from, states::NTuple{N}, ::Type{T}) where {N,T}
    empty_row = ntuple(_ -> zero(T), Val(N))
    return Experimental.fold_row(empty_row, Experimental.transitions(life, interval, from), from, interval, T) do row, dest, q
        j = findfirst(isequal(dest), states)
        isnothing(j) && throw(ArgumentError("$dest is not one of the life's states $states"))
        Base.setindex(row, row[j] + q, j)
    end
end

state_total(contract, t, state) = sum(map(c -> Experimental.state_amount(c, t, state), values(contract)))
edge_total(contract, interval, from, to) = sum(map(c -> Experimental.transition_amount(c, interval, from, to), values(contract)))

function active_mass(mass::NTuple{N,T}, life, states) where {N,T}
    total = sum(i -> active(life, states[i]) ? mass[i] : zero(T), 1:N)
    iszero(total) && throw(DomainError(total, "cannot condition on an event of probability zero"))
    return ntuple(i -> active(life, states[i]) ? mass[i] / total : zero(T), Val(N))
end

# Function barriers keep rolling tuple bindings out of closures captured by the loop.
fixed_step_rows(life, interval, states::NTuple{N}, mask, zero_mass, ::Type{T}) where {N,T} =
    ntuple(i -> has_state(mask, i) ? fixed_row(life, interval, states[i], states, T) : zero_mass, Val(N))

advance_mass(mass::NTuple{N}, rows) where {N} =
    ntuple(j -> sum(i -> mass[i] * rows[i][j], 1:N), Val(N))

function fixed_step_values(b, p, states::NTuple{N}, t, interval, d, rows, next_values,
                           mask, ::Type{T}) where {N,T}
    return ntuple(Val(N)) do i
        has_state(mask, i) || return zero(T)
        s = states[i]
        v = state_total(b.contract, t, s) + state_total(p.contract, t, s)
        if !isnothing(interval)
            continuation = zero(T)
            for j in 1:N
                q = rows[i][j]
                iszero(q) && continue
                payment = edge_total(b.contract, interval, s, states[j]) + edge_total(p.contract, interval, s, states[j])
                continuation += q * (payment + next_values[j])
            end
            v += d * continuation
        end
        return convert(T, v)
    end
end

# The union of annual prefix ranges and integer queries is still an integer range.
# Preserve it rather than sorting copies and invoking fractional-age mortality methods.
yearly_grid(grid::AbstractRange) = first(grid) == 0 && step(grid) == 1 && isinteger(last(grid))
yearly_grid(grid) = false
function policy_grid(bgrid, pgrid, query_times, known_state)
    if yearly_grid(bgrid) && yearly_grid(pgrid)
        start = known_state ? first(query_times) : 0
        return start:Int(max(last(bgrid), last(pgrid), last(query_times)))
    end
    grid = sort!(unique!([collect(bgrid); collect(pgrid); query_times]))
    return known_state ? filter(t -> t >= first(query_times), grid) : grid
end

function fixed_policy_values(b, p, bdates, pdates, life, curve, times, state, phase,
                             states::NTuple{N,S}, ::Type{T}) where {N,S,T}
    result = zeros(T, length(times))
    for product in (b, p), c in values(product.contract)
        c isa CertainPayment && certain_tails!(result, c, curve, times, product.due && phase === :before)
    end
    queries = [i for i in eachindex(times) if outstanding(bdates, b.due, times[i], phase) || outstanding(pdates, p.due, times[i], phase)]
    isempty(queries) && return result
    sort!(queries; by=i -> times[i])
    horizon = max(last(b.grid), last(p.grid))
    query_times = [times[i] for i in queries]
    grid = policy_grid(b.grid, p.grid, query_times, !isnothing(state))
    stop = searchsortedlast(grid, horizon)
    # Explicit late states need no mortality if only certain payments remain.
    !isnothing(state) && iszero(stop) && return result
    rows = Vector{NTuple{N,NTuple{N,T}}}(undef, max(0, stop-1))
    masks = zeros(UInt8, stop)
    weights = Vector{NTuple{N,T}}(undef, length(times))
    zero_mass = ntuple(_ -> zero(T), Val(N))
    empty_rows = ntuple(_ -> zero_mass, Val(N))
    current = isnothing(state) ? state_mass(findfirst(isequal(starting_state(life)), states), Val(N), T) : zero_mass
    known = isnothing(state) ? zero_mass : state_mass(findfirst(isequal(state), states), Val(N), T)
    needed = UInt8(0)
    cursor = 1
    for k in eachindex(grid)
        t = grid[k]
        while cursor <= length(queries) && times[queries[cursor]] == t
            i = queries[cursor]
            weights[i] = isnothing(state) ? active_mass(current, life, states) : known
            k <= stop && (needed |= mass_mask(weights[i]))
            cursor += 1
        end
        k <= stop && (masks[k] = needed)
        k == length(grid) && break
        # Occupancy ends at the final conditioning date; value reachability ends at
        # the final contingent payment. Neither asks for unused mortality rows.
        occupancy_needed = isnothing(state) && t < last(query_times)
        row_mask = (k < stop ? needed : UInt8(0)) | (occupancy_needed ? mass_mask(current) : UInt8(0))
        interval = Experimental.Interval(t, grid[k+1])
        step_rows = fixed_step_rows(life, interval, states, row_mask, zero_mass, T)
        k < stop && (rows[k] = step_rows)
        current = occupancy_needed ? advance_mass(current, step_rows) : zero_mass
        next_needed = UInt8(0)
        if k < stop
            for i in 1:N
                has_state(needed, i) && (next_needed |= mass_mask(step_rows[i]))
            end
        end
        needed = next_needed
    end
    iszero(stop) && return result
    next_values = zero_mass
    cursor = searchsortedlast(query_times, horizon)
    for k in stop:-1:1
        t = grid[k]
        interval = k < stop ? Experimental.Interval(t, grid[k+1]) : nothing
        d = k < stop && !iszero(masks[k]) ? discount(curve, t, grid[k+1]) : one(T)
        step_rows = k < stop ? rows[k] : empty_rows
        before = fixed_step_values(b, p, states, t, interval, d, step_rows, next_values, masks[k], T)
        while cursor >= 1 && query_times[cursor] == t
            output = queries[cursor]
            value = zero(T)
            for i in 1:N
                q = weights[output][i]
                iszero(q) && continue
                s = states[i]
                v = before[i]
                (b.due && phase === :before) || (v -= state_total(b.contract, t, s))
                (p.due && phase === :before) || (v -= state_total(p.contract, t, s))
                value += q * v
            end
            result[output] += value
            cursor -= 1
        end
        next_values = before
    end
    return result
end
