# 'actuarial objects' that combine multiple forms of decrements (lapse, interest, death, etc)
abstract type Life end


"""
    SingleLife(mortality; issue_age, alive=true, fractional_assump=UniformDeaths())
    SingleLife(; mortality, issue_age, alive=true, fractional_assump=UniformDeaths())

A `Life` object containing the necessary assumptions for contingent maths related to a single life. Use with a `LifeContingency` to do many actuarial present value calculations.

`mortality` is one of:
- a vector of rates indexed by attained age, such as `table.ultimate` or `table.select[30]`. `issue_age` defaults to the vector's first age.
- a select table's vector of rate vectors, such as `table.select`. `issue_age` picks the row, and defaults to the first issue age.
- a parametric model from MortalityTables, such as `MortalityTables.Gompertz(a=0.0002, b=0.13)`. `issue_age` is required.

Keyword arguments:
- `issue_age` is the assumed issue age for the `SingleLife` and is the basis of many contingency calculations.
- `alive` (default `true`) is the life's status at issue. A life that is not alive has `survival(life, t) == 0` for every `t`; `survival(life, from, to)` is still the mortality assumption's survival for a life alive at `from`. Useful for joint lives with different statuses.
- `fractional_assump`. Default value is `UniformDeaths()`. This is a `DeathDistribution` from the `MortalityTables.jl` package and is the assumption to use for non-integer ages/times.

# Examples

```jldoctest
julia> vbt = MortalityTables.table("2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB");

julia> SingleLife(vbt.select[30]).issue_age        # select rates for issue age 30
30

julia> SingleLife(vbt.select, issue_age=30).mortality == vbt.select[30]   # the same, picking the row by issue age
true

julia> survival(SingleLife(mortality=vbt.ultimate, issue_age=30), 10)
0.9894404665434904

julia> survival(SingleLife(MortalityTables.Gompertz(a=0.0002, b=0.13), issue_age=40), 10)
0.4750123629834455
```
"""
struct SingleLife{M,D} <: Life
    mortality::M
    issue_age::Int
    alive::Bool
    fractional_assump::D
end

SingleLife(; mortality, kwargs...) = SingleLife(mortality; kwargs...)

function SingleLife(mortality::AbstractVector; issue_age=firstindex(mortality), alive=true, fractional_assump=mt.UniformDeaths())
    issue_age isa Integer && firstindex(mortality) <= issue_age <= lastindex(mortality) ||
        throw(ArgumentError("`issue_age` must be an integer within the rate ages $(firstindex(mortality)):$(lastindex(mortality)); got $issue_age"))
    return SingleLife(mortality, issue_age, alive, fractional_assump)
end

# a select table: one vector of rates per issue age
function SingleLife(mortality::AbstractVector{<:AbstractVector}; issue_age=firstindex(mortality), kwargs...)
    issue_age isa Integer && checkbounds(Bool, mortality, issue_age) ||
        throw(ArgumentError("`issue_age` is outside the select table: $issue_age"))
    return SingleLife(mortality[issue_age]; issue_age, kwargs...)
end

function SingleLife(mortality::mt.ParametricMortality; issue_age, alive=true, fractional_assump=mt.UniformDeaths())
    issue_age isa Integer && issue_age >= 0 || throw(ArgumentError("`issue_age` must be a nonnegative integer; got $issue_age"))
    return SingleLife(mortality, issue_age, alive, fractional_assump)
end

SingleLife(::mt.MortalityTable; kwargs...) =
    throw(ArgumentError("pass a vector of rates, such as `table.ultimate` or `table.select[issue_age]`, rather than the whole table"))

"""
    JointAssumption()

An abstract type representing the different assumed relationship between the survival of the lives on a JointLife. Available options to use include:
- `Frasier()`
"""
abstract type JointAssumption end

"""
    Independent()

The assumption of independent lives in a joint life calculation.
Is a subtype of `JointAssumption`.
"""
struct Independent <: JointAssumption end

"""Compatibility alias for [`Independent`](@ref), the assumption of independent lives."""
const Frasier = Independent

"""
    Contingency()

An abstract type representing the different triggers for contingent benefits. Available options to use include:
- `LastSurvivor()`
- `FirstToDie()`
"""
abstract type Contingency end

"""
    LastSurvivor()
The contingency whereupon benefits are payable upon both lives passing.
Is a subtype of `Contingency`
"""
struct LastSurvivor <: Contingency end

"""
    FirstToDie()
The contingency whereupon benefits are payable upon the first life passing.
Is a subtype of `Contingency`
"""
struct FirstToDie <: Contingency end

"""
    JointLife(; lives, contingency, joint_assumption=Independent())

A `Life` object containing the necessary assumptions for contingent maths related to a joint life insurance. Use with a `LifeContingency` to do many actuarial present value calculations.

Keyword arguments:
- `lives` is a tuple of two `SingleLife`s
- `contingency` is required. It is the trigger for contingent benefits: `LastSurvivor()` or `FirstToDie()`. See `?Contingency`.
- `joint_assumption` Default value is `Independent()`, independent lives, the only assumption implemented. See `?JointAssumption`.

# Examples

```jldoctest
julia> vbt = MortalityTables.table("2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB");

julia> lives = (SingleLife(vbt.select[30]), SingleLife(vbt.select[35]));

julia> survival(JointLife(lives=lives, contingency=LastSurvivor()), 40)                           # at least one alive
0.935943451146974

julia> survival(JointLife(lives=lives, contingency=FirstToDie()), 40)  # both alive
0.5468053463643783
```
"""
struct JointLife{L<:Tuple{SingleLife,SingleLife},C<:Contingency,J<:JointAssumption} <: Life
    lives::L
    contingency::C
    joint_assumption::J
end

function JointLife(; lives, contingency=nothing, joint_assumption=Independent())
    isnothing(contingency) && throw(ArgumentError("specify contingency=FirstToDie() or contingency=LastSurvivor()"))
    return JointLife(lives, contingency, joint_assumption)
end

JointLife(l1::SingleLife, l2::SingleLife; kwargs...) = JointLife(; lives=(l1, l2), kwargs...)

# A rate vector's last rate covers the year from its last age, while a parametric law ends at
# its own `omega`, the last age at which it is defined.
mt.omega(l::SingleLife) = mt.omega(l.mortality) - l.issue_age + 1
mt.omega(l::SingleLife{<:mt.ParametricMortality}) = mt.omega(l.mortality) - l.issue_age

mt.omega(l::JointLife) = horizon(l.contingency, map(omega, l.lives))

# A joint status lasts as long as its contingency can still be active.
horizon(::LastSurvivor, omegas) = maximum(omegas)
horizon(::FirstToDie, omegas) = minimum(omegas)

"""
    survival(life::SingleLife, to_time)
    survival(life::SingleLife, from_time, to_time)

Times are durations in years from issue. With one time, use the observed status at issue:
`alive=false` gives zero, while `alive=true` uses the mortality assumption from issue.

With two times, ask the hypothetical question of surviving to `to_time` if alive at
`from_time`. This uses the mortality assumption alone, regardless of the recorded `alive`
flag. A positive result for an initially dead life does not change its status or imply
that it can become alive. Use the one-time form or product valuation when the observed
starting status should determine the result.
"""
mt.survival(l::SingleLife, to_time) = l.alive ? survival(l, 0, to_time) : zero(survival(l, 0, 0))
mt.survival(l::SingleLife, from_time, to_time) = survival(l.mortality, l.issue_age + from_time, l.issue_age + to_time, l.fractional_assump)

# Past the last rate, survival is known only once a rate of one has established extinction.
function mt.survival(l::SingleLife{<:AbstractVector}, from_time, to_time)
    from_age, to_age = l.issue_age + from_time, l.issue_age + to_time
    to_age <= lastindex(l.mortality) + 1 || return survival_past_table(l, from_age, to_age)
    return survival(l.mortality, from_age, to_age, l.fractional_assump)
end

# kept out of line so that the common case above stays small enough to inline
@noinline function survival_past_table(l::SingleLife, from_age, to_age)
    certain = survival(l.mortality, l.issue_age, l.issue_age, l.fractional_assump)
    from_age == to_age && return certain
    isnothing(extinction_age(l)) && throw(DomainError(to_age,
        "the mortality rates end at age $(lastindex(l.mortality)) without reaching a rate of 1, so survival to age $to_age is unknown; supply rates that cover it"))
    return zero(certain)
end

# The first age by which everyone has died, or `nothing` if the rates never reach one.
function extinction_age(l::SingleLife{<:AbstractVector})
    for age in l.issue_age:lastindex(l.mortality)
        l.mortality[age] >= 1 && return age + 1
    end
    return nothing
end

"""
    survival(life)

Return a survival vector for the given life.
"""
function mt.survival(l::L) where {L<:Life}
    ω = omega(l)
    isfinite(ω) || throw(DomainError(ω, "supply explicit finite dates, for example survival.(life, 0:20), for an unbounded mortality law"))
    return Iterators.map(t -> survival(l, t), 0:ω)
end

"""
    survival(life::JointLife, to_time)
    survival(life::JointLife, from_time, to_time)

With one time, the probability that `life`'s contingency is still active at `to_time`, given
each life's status at issue. With two, that probability conditional on the contingency being
active at `from_time`. This conditions on the joint status alone, not on which lives are
alive. Throws a `DomainError` when the contingency cannot be active at `from_time`.
"""
function mt.survival(l::JointLife, to_time)
    statuses = joint_statuses(l.joint_assumption, map(life -> survival(life, to_time), l.lives))
    return sum(p for (status, p) in statuses if active(l.contingency, status))
end

function mt.survival(l::JointLife, from_time, to_time)
    active_then = survival(l, from_time)
    iszero(active_then) &&
        throw(DomainError(from_time, "the contingency cannot be active at time $from_time, so survival conditional on it is undefined"))
    return survival(l, to_time) / active_then
end

# The probability of each pair of statuses, given each life's probability of being alive.
joint_statuses(::Frasier, (p1, p2)) = (
    (:alive, :alive) => p1 * p2,
    (:alive, :dead) => p1 * (1 - p2),
    (:dead, :alive) => (1 - p1) * p2,
    (:dead, :dead) => (1 - p1) * (1 - p2),
)
joint_statuses(assumption::JointAssumption, probabilities) = unsupported(assumption)

unsupported(assumption) =
    throw(ArgumentError("$(nameof(typeof(assumption))) is not implemented; the supported joint assumption is Frasier(), for independent lives"))

# Whether the contingency is still active, given each life's status.
active(::LastSurvivor, statuses) = any(==(:alive), statuses)
active(::FirstToDie, statuses) = all(==(:alive), statuses)

# Whether a life is still in force in an engine state.
active(::SingleLife, state) = state === :alive
active(l::JointLife, state) = active(l.contingency, state)

## Lives as models for the experimental engine. A single life is `:alive` or `:dead`; a
## joint life's state is the pair of its lives' statuses.

# Each life's status at issue, as a distribution for `Experimental.project`.
initial_distribution(l::SingleLife) = [(l.alive ? :alive : :dead) => one(survival(l, 0, 0))]
initial_distribution(l::JointLife) =
    [map(life -> life.alive ? :alive : :dead, l.lives) => prod(life -> one(survival(life, 0, 0)), l.lives)]

Experimental.states(::SingleLife) = (:alive, :dead)
Experimental.states(::JointLife) = ((:alive, :alive), (:alive, :dead), (:dead, :alive), (:dead, :dead))

# The dead stay dead without consulting the mortality rates, so being dead is valid past
# the end of any table.
function Experimental.transitions(l::SingleLife, interval::Experimental.Interval, state::Symbol)
    if state === :dead
        certain = survival(l, interval.start, interval.start)
        return (:alive => zero(certain), :dead => certain)
    end
    state === :alive || throw(ArgumentError("a single life's state is :alive or :dead; got $state"))
    p = survival(l, interval.start, interval.stop)
    return (:alive => p, :dead => one(p) - p)
end

Experimental.transitions(l::JointLife, interval::Experimental.Interval, state::Tuple{Symbol,Symbol}) =
    joint_row(l.joint_assumption, l.lives, interval, state)

# Independent lives move independently: the joint row is the product of the lives' rows.
function joint_row(::Frasier, lives, interval, state)
    first_row, second_row = map((life, status) -> Experimental.transitions(life, interval, status), lives, state)
    return ((first(a), first(b)) => last(a) * last(b) for a in first_row, b in second_row)
end
joint_row(assumption, lives, interval, state) = unsupported(assumption)
