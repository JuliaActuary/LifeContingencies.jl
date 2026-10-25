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
    using MortalityTables
    vbt = MortalityTables.table("2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB")

    SingleLife(vbt.select[30])                        # select rates for issue age 30
    SingleLife(vbt.select, issue_age=30)              # the same, picking the row by issue age
    SingleLife(mortality=vbt.ultimate, issue_age=30)
"""
struct SingleLife{M,D} <: Life
    mortality::M
    issue_age::Int
    alive::Bool
    fractional_assump::D
end

SingleLife(; mortality, kwargs...) = SingleLife(mortality; kwargs...)

function SingleLife(mortality::AbstractVector; issue_age=firstindex(mortality), alive=true, fractional_assump=mt.UniformDeaths())
    return SingleLife(mortality, issue_age, alive, fractional_assump)
end

# a select table: one vector of rates per issue age
SingleLife(mortality::AbstractVector{<:AbstractVector}; issue_age=firstindex(mortality), kwargs...) =
    SingleLife(mortality[issue_age]; issue_age, kwargs...)

function SingleLife(mortality::mt.ParametricMortality; issue_age, alive=true, fractional_assump=mt.UniformDeaths())
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
    Frasier()

The assumption of independent lives in a joint life calculation.
Is a subtype of `JointAssumption`.
"""
struct Frasier <: JointAssumption end

""" 
    Contingency()

An abstract type representing the different triggers for contingent benefits. Available options to use include:
- `LastSurvivor()`
"""
abstract type Contingency end

"""
    LastSurvivor()
The contingency whereupon benefits are payable upon both lives passing.
Is a subtype of `Contingency`
"""
struct LastSurvivor <: Contingency end

# TODO: Not Implemented
# """
#     FirstToDie()
# The contingency whereupon benefits are payable upon the first life passing.

# Is a subtype of `Contingency`
# """
# struct FirstToDie <: Contingency end

"""
    struct JointLife
        lives
        contingency
        joint_assumption
    end

    A `Life` object containing the necessary assumptions for contingent maths related to a joint life insurance. Use with a `LifeContingency` to do many actuarial present value calculations. 

Keyword arguments:
- `lives` is a tuple of two `SingleLife`s
- `contingency` default is `LastSurvivor()`. It is the trigger for contingent benefits. See `?Contingency`. 
- `joint_assumption` Default value is `Frasier()`. It is the assumed relationship between the mortality of the two lives. See `?JointAssumption`. 

# Examples
    using MortalityTables
    mortality = MortalityTables.table("2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB")

    l1 = SingleLife(
        mortality       = mortality.select[30], 
        issue_age  = 30          
    )
    l2 = SingleLife(
        mortality       = mortality.select[30], 
        issue_age  = 30          
    )

    jl = JointLife(
        lives = (l1,l2),
        contingency = LastSurvivor(),
        joint_assumption = Frasier()
    )
"""
Base.@kwdef struct JointLife{C<:Contingency,J<:JointAssumption} <: Life
    lives::Tuple{SingleLife,SingleLife}
    contingency::C = LastSurvivor()
    joint_assumption::J = Frasier()
end

function mt.omega(l::SingleLife)
    return mt.omega(l.mortality) - l.issue_age + 1
end

function mt.omega(l::JointLife)
    return minimum(omega.(l.lives))
end

"""
    survival(life::SingleLife, to_time)
    survival(life::SingleLife, from_time, to_time)

With one time, the probability that `life` is alive at `to_time`, given its status at issue.
With two, the probability of surviving from `from_time` to `to_time` for a life alive at
`from_time`, which depends only on the mortality assumption.
"""
mt.survival(l::SingleLife, to_time) = l.alive ? survival(l, 0, to_time) : zero(survival(l, 0, 0))
mt.survival(l::SingleLife, from_time, to_time) = survival(l.mortality, l.issue_age + from_time, l.issue_age + to_time, l.fractional_assump)

# Past the last rate, survival is known only once a rate of one has established extinction.
function mt.survival(l::SingleLife{<:AbstractVector}, from_time, to_time)
    from_age, to_age = l.issue_age + from_time, l.issue_age + to_time
    to_age <= lastindex(l.mortality) + 1 && return survival(l.mortality, from_age, to_age, l.fractional_assump)
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
    return Iterators.map(t -> survival(l, t), 0:ω)
end

mt.survival(l::JointLife, to_time) = survival(l.contingency, l.joint_assumption, l, to_time)
function mt.survival(l::JointLife, from_time, to_time)
    return survival(l.contingency, l.joint_assumption, l::JointLife, from_time, to_time)
end

function mt.survival(ins::LastSurvivor, assump::JointAssumption, l::JointLife, from_time, to_time)
    a = survival(ins, assump, l, from_time)
    b = survival(ins, assump, l, to_time)
    return b / a
end

function mt.survival(ins::LastSurvivor, assump::JointAssumption, l::JointLife, to_time)
    l1, l2 = l.lives
    ₜpₓ = survival(l1, to_time)
    ₜpᵧ = survival(l2, to_time)
    return ₜpₓ + ₜpᵧ - ₜpₓ * ₜpᵧ
end
