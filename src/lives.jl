# 'actuarial objects' that combine multiple forms of decrements (lapse, interest, death, etc)
abstract type Life end


"""
    struct SingleLife
        mortality
        issue_age::Int
        alive::Bool
        fractional_assump::MortalityTables.DeathDistribution
    end

A `Life` object containing the necessary assumptions for contingent maths related to a single life. Use with a `LifeContingency` to do many actuarial present value calculations. 

Keyword arguments:
- `mortality` pass a mortality vector, which is an array of applicable mortality rates indexed by attained age
- `issue_age` is the assumed issue age for the `SingleLife` and is the basis of many contingency calculations.
- `alive` Default value is `true`. Useful for joint insurances with different status on the lives insured.
- `fractional_assump`. Default value is `UniformDeaths()`. This is a `DeathDistribution` from the `MortalityTables.jl` package and is the assumption to use for non-integer ages/times.

# Examples
    using MortalityTables
    mortality = MortalityTables.table("2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB")

    SingleLife(
        mort       = mort.select[30], 
        issue_age  = 30          
    )
"""
struct SingleLife{M,D} <: Life
    mortality::M
    issue_age::Int
    alive::Bool
    fractional_assump::D
end

function SingleLife(; mortality, issue_age=nothing, alive=true, fractional_assump=mt.UniformDeaths())
    return SingleLife(mortality; issue_age, alive, fractional_assump)
end

function SingleLife(mortality; issue_age=nothing, alive=true, fractional_assump=mt.UniformDeaths())
    if isnothing(issue_age)
        issue_age = firstindex(mortality)
    end

    if !(eltype(mortality) <: Real)
        # most likely case is that mortality is an array of vectors
        # use issue age to select the right one (assuming indexed with issue age
        return SingleLife(mortality[issue_age], issue_age, alive, fractional_assump)
    else
        return SingleLife(mortality, issue_age, alive, fractional_assump)
    end

end

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

mt.survival(l::SingleLife, to_time) = survival(l, 0, to_time)
mt.survival(l::SingleLife, from_time, to_time) = survival(l.mortality, l.issue_age + from_time, l.issue_age + to_time, l.fractional_assump)

"""
    survival(life)

Return a survival vector for the given life.
"""
function mt.survival(l::L) where {L<:Life}
    ω = omega(l)
    return Iterators.map(t -> survival(l, t), 0:ω)
end

mt.survival(l::JointLife, to_time) = survival(l::JointLife, 0, to_time)
function mt.survival(l::JointLife, from_time, to_time)
    return survival(l.contingency, l.joint_assumption, l::JointLife, from_time, to_time)
end

function mt.survival(ins::LastSurvivor, assump::JointAssumption, l::JointLife, from_time, to_time)
    a = survival(ins, assump, l, from_time)
    b = survival(ins, assump, l, to_time)
    return b / a
end

function mt.survival(ins::LastSurvivor, assump::JointAssumption, l::JointLife, to_time)
    to_time == 0 && return 1.0

    l1, l2 = l.lives
    ₜpₓ = survival(l1.mortality, l1.issue_age, l1.issue_age + to_time, l1.fractional_assump)
    ₜpᵧ = survival(l2.mortality, l2.issue_age, l2.issue_age + to_time, l2.fractional_assump)
    return ₜpₓ + ₜpᵧ - ₜpₓ * ₜpᵧ
end
