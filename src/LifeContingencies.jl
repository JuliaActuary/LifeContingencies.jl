module LifeContingencies

using ActuaryUtilities
using MortalityTables
using Transducers
using Dates
using Yields

const mt = MortalityTables

export LifeContingency,
    Insurance, AnnuityDue, AnnuityImmediate,
    APV,
    SingleLife, Frasier, JointLife,
    LastSurvivor,
    survival,
    reserve_premium_net,
    insurance,
    annuity_due,
    annuity_immediate,
    premium_net,
    omega,
    survival,
    discount,
    benefit,
    probability,
    cashflows,
    cashflows,
    timepoints,
    present_value





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
- `fractional_assump`. Default value is `Uniform()`. This is a `DeathDistribution` from the `MortalityTables.jl` package and is the assumption to use for non-integer ages/times.

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

function SingleLife(; mortality, issue_age = nothing, alive = true, fractional_assump = mt.Uniform())
    return SingleLife(mortality; issue_age, alive, fractional_assump)
end

function SingleLife(mortality; issue_age = nothing, alive = true, fractional_assump = mt.Uniform())
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

"""
    struct LifeContingency
        life::Life
"""
struct LifeContingency{L,Y}
    life::L
    int::Y
end

Base.broadcastable(lc::LifeContingency) = Ref(lc)

"""
    omega(lc::LifeContingency)
    omega(l::Life)
    omega(i::InterestRate)

# `Life`s and `LifeContingency`s

Returns the last defined time_period for both the interest rate and mortality table.
Note that this is *different* than calling `omega` on a `MortalityTable`, which will give you the last `attained_age`.

Example: if the `LifeContingency` has issue age 60, and the last defined attained age for the `MortalityTable` is 100, then `omega` of the `MortalityTable` will be `100` and `omega` of the 
`LifeContingency` will be `40`.

# `InterestRate`s

The last period that the interest rate is defined for. Assumed to be infinite (`Inf`) for 
    functional and constant interest rate types. Returns the `lastindex` of the vector if 
    a vector type.
"""
function mt.omega(lc::LifeContingency)
    # if one of the omegas is infinity, that's a Float so we need
    # to narrow the type with Int
    return Int(omega(lc.life))
end

function mt.omega(l::SingleLife)
    return mt.omega(l.mortality) - l.issue_age + 1
end

function mt.omega(l::JointLife)
    return minimum(omega.(l.lives))
end


###################
## COMMUTATIONS ###
###################

"""
    D(lc::LifeContingency, to_time)

``D_x`` is a retrospective actuarial commutation function which is the product of the survival and discount factor.
"""
function D(lc::LifeContingency, to_time)
    return discount(lc.int, to_time) * survival(lc, to_time)
end


"""
    l(lc::LifeContingency, to_time)

``l_x`` is a retrospective actuarial commutation function which is the survival up to a certain point in time. By default, will have a unitary basis (ie `1.0`), but you can specify `basis` keyword argument to use something different (e.g. `1000` is common in the literature.)
"""
function l(lc::LifeContingency, to_time; basis = 1.0)
    return survival(lc.life, to_time) * basis
end

"""
    C(lc::LifeContingency, to_time)

``C_x`` is a retrospective actuarial commutation function which is the product of the discount factor and the difference in `l` (``l_x``).
"""
function C(lc::LifeContingency, to_time)
    discount(lc.int, to_time + 1) * (l(lc, to_time) - l(lc, to_time + 1))

end

"""
    N(lc::LifeContingency, from_time)

``N_x`` is a prospective actuarial commutation function which is the sum of the `D` (``D_x``) values from the given time to the end of the mortality table.
"""
function N(lc::LifeContingency, from_time)
    range = from_time:(omega(lc)-1)
    vals = Iterators.map(from_time -> D(lc, from_time), range)
    return sum(vals)
end

"""
    M(lc::LifeContingency, from_time)

The ``M_x`` actuarial commutation function where the `from_time` argument is `x`.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
function M(lc::LifeContingency, from_time)
    range = from_time:omega(lc)-1
    vals = Iterators.map(from_time -> C(lc, from_time), range)
    return sum(vals)
end

E(lc::LifeContingency, t, x) = D(lc, x + t) / D(lc, x)


##################
### Insurances ###
##################

abstract type Insurance end

function LifeContingency(ins::I) where {I<:Insurance}
    LifeContingency(ins.life, ins.int)
end

struct WholeLife{L,Y} <: Insurance
    life::L
    int::Y
end

struct Term{L,Y} <: Insurance
    life::L
    int::Y
    term::Int
end

"""
    Insurance(lc::LifeContingency, term)
    Insurance(life,interest, term)
    Insurance(lc::LifeContingency)
    Insurance(life,interest)

Life insurance with a term period of `term`. If `term` is `nothing`, then whole life insurance.

Issue age is based on the `issue_age` in the LifeContingency `lc`.

# Examples

```
ins = Insurance(
    SingleLife(mortality = UltimateMortality([0.5,0.5]),issue_age = 0),
    Yields.Constant(0.05),
    1           # 1 year term
) 
```
"""
Insurance(lc::LifeContingency, term) = Insurance(lc.life, lc.int, term)
Insurance(lc::LifeContingency) = Insurance(lc.life, lc.int)

function Insurance(life, int, term::Int)
    term < 1 && return ZeroBenefit(life, int)
    return Term(life, int, term)
end
function Insurance(life, int)
    return WholeLife(life, int)
end

abstract type AnnuityKind end
struct Due <: AnnuityKind end
struct Immediate <: AnnuityKind end

abstract type AnnuityPayable end
abstract type AnnuityCertain <: AnnuityPayable end

struct TermCertain <: AnnuityCertain
    term::Int
    certain::Int
end
struct LifeCertain <: AnnuityCertain
    certain::Int
end
struct TermAnnuity <: AnnuityPayable
    term::Int
end
struct LifeAnnuity <: AnnuityPayable end

struct Annuity{L,Y,K<:AnnuityKind,P<:AnnuityPayable} <: Insurance
    life::L
    int::Y
    kind::K
    payable::P
    start_time::Int
    frequency::Int
end
struct ZeroBenefit{L,Y} <: Insurance
    life::L
    int::Y
end

function ZeroBenefit(lc::LifeContingency)
    return ZeroBenefit(lc.life, lc.int)
end

"""
    AnnuityDue(lc::LifeContingency; n=nothing, start_time=0; certain=nothing,frequency=1)
    AnnuityDue(life, interest; n=nothing, start_time=0; certain=nothing,frequency=1)

Annuity due with the benefit period starting at `start_time` and ending after `n` periods with `frequency` payments per year of `1/frequency` amount and a `certain` period with non-contingent payments. 

# Examples

```
ins = AnnuityDue(
    SingleLife(mortality = UltimateMortality([0.5,0.5]),issue_age = 0),
    Yields.Constant(0.05),
    1, # term of policy
) 
```
"""
function AnnuityDue(life, int, term; certain = nothing, start_time = 0, frequency = 1)
    term < 1 && return ZeroBenefit(life, int)
    if isnothing(certain)
        Annuity(life, int, Due(), TermAnnuity(term), start_time, frequency)
    else
        Annuity(life, int, Due(), TermCertain(term, certain), start_time, frequency)
    end
end

function AnnuityDue(life, int; certain = nothing, start_time = 0, frequency = 1)
    if isnothing(certain)
        Annuity(life, int, Due(), LifeAnnuity(), start_time, frequency)
    else
        Annuity(life, int, Due(), LifeCertain(certain), start_time, frequency)
    end
end

function AnnuityDue(lc::L, term; certain = nothing, start_time = 0, frequency = 1) where {L<:LifeContingency}
    return AnnuityDue(lc.life, lc.int, term; certain, start_time, frequency)
end

function AnnuityDue(lc::L; certain = nothing, start_time = 0, frequency = 1) where {L<:LifeContingency}
    return AnnuityDue(lc.life, lc.int; certain, start_time, frequency)
end

"""
    AnnuityImmediate(lc::LifeContingency; term=nothing, start_time=0; certain=nothing,frequency=1)
    AnnuityImmediate(life, interest; term=nothing, start_time=0; certain=nothing,frequency=1)

Annuity immediate with the benefit period starting at `start_time` and ending after `term` periods with `frequency` payments per year of `1/frequency` amount and a `certain` period with non-contingent payments. 

# Examples

```
ins = AnnuityImmediate(
    SingleLife(mortality = UltimateMortality([0.5,0.5]),issue_age = 0),
    Yields.Constant(0.05),
    1 # term of policy
) 
```

"""
function AnnuityImmediate(life, int, term; certain = nothing, start_time = 0, frequency = 1)
    term < 1 && return ZeroBenefit(life, int)
    if isnothing(certain)
        Annuity(life, int, Immediate(), TermAnnuity(term), start_time, frequency)
    else
        Annuity(life, int, Immediate(), TermCertain(term, certain), start_time, frequency)
    end
end

function AnnuityImmediate(life, int; certain = nothing, start_time = 0, frequency = 1)
    if isnothing(certain)
        Annuity(life, int, Immediate(), LifeAnnuity(), start_time, frequency)
    else
        Annuity(life, int, Immediate(), LifeCertain(certain), start_time, frequency)
    end
end

function AnnuityImmediate(lc::L, term; certain = nothing, start_time = 0, frequency = 1) where {L<:LifeContingency}
    return AnnuityImmediate(lc.life, lc.int, term; certain, start_time, frequency)
end

function AnnuityImmediate(lc::L; certain = nothing, start_time = 0, frequency = 1) where {L<:LifeContingency}
    return AnnuityImmediate(lc.life, lc.int; certain, start_time, frequency)
end

"""
    survival(Insurance,time)

The survivorship for the given insurance from time zero to `time`.

"""
function MortalityTables.survival(ins::I, t) where {I<:Insurance}
    survival(ins.life,t)
end

"""
    survival(Insurance)

The survivorship vector for the given insurance.

To get the fully computed and allocated vector, call `collect(survival(...))`.
"""
function MortalityTables.survival(ins::I) where {I<:Insurance}
    return Iterators.map(t -> survival(ins, t - 1), timepoints(ins))
end

function MortalityTables.survival(ins::A) where {A<:Annuity}
    return Iterators.map(t -> survival(ins, t), timepoints(ins))
end


"""
    discount(Insurance)

The discount vector for the given insurance.

To get the fully computed and allocated vector, call `collect(discount(...))`.
"""
function Yields.discount(ins::I) where {I<:Insurance}
    return Iterators.map(t -> Yields.discount.(ins.int, t), timepoints(ins))
end


"""
    benefit(Insurance)

The unit benefit for the given insurance.
"""
function benefit(ins::I) where {I<:Insurance}
    return 1.0
end

function benefit(ins::ZeroBenefit)
    return 0.0
end

function benefit(ins::Annuity)
    return 1.0 / ins.frequency
end


"""
    probability(Insurance)

The vector of contingent benefit probabilities for the given insurance.

To get the fully computed and allocated vector, call `collect(probability(...))`.
"""
function probability(ins::I) where {I<:Insurance}
    return Iterators.map(timepoints(ins)) do t
        survival(ins.life, t - 1) * decrement(ins.life, t - 1, t)
    end
end

function probability(ins::ZeroBenefit)
    return Iterators.repeated(1.0, length(timepoints(ins)))
end

function probability(ins::Annuity)
    return probability(ins.payable, ins)
end

function probability(ap::AP, ins::Annuity) where {AP<:AnnuityPayable}
    return Iterators.map(t -> survival(ins.life, t), timepoints(ins))
end

function probability(ap::AP, ins::Annuity) where {AP<:AnnuityCertain}
    return Iterators.map(timepoints(ins)) do t
        t <= ap.certain + ins.start_time ? 1.0 : survival(ins.life, t)
    end
end


"""
    cashflows(Insurance)

The vector of decremented benefit cashflows for the given insurance. 

To get the fully computed and allocated vector, call `collect(cashflows(...))`.
"""
function cashflows(ins::I) where {I<:Insurance}
    b = benefit(ins)
    return Iterators.map(p -> p * b, probability(ins))
end


"""
    timepoints(Insurance)

The vector of times corresponding to the cashflow vector for the given insurance.

To get the fully computed and allocated vector, call `collect(timepoints(...))`.
"""
function timepoints(ins::Insurance)::UnitRange{Int64}
    return 1:omega(ins.life)
end

function timepoints(ins::Term)::UnitRange{Int64}
    return 1:min(omega(ins.life), ins.term)
end

function timepoints(ins::ZeroBenefit)
    return Iterators.repeated(0.0, 1)
end

function timepoints(ins::Annuity)
    return timepoints(ins, ins.kind)
end

function timepoints(ins::Annuity, kind::K) where {K<:AnnuityKind}
    return timepoints(ins.payable, ins, kind)
end

function timepoints(ap::LifeCertain, ins::Annuity, ::Due)
    end_time = omega(ins.life)
    timestep = 1 / ins.frequency
    return ins.start_time:timestep:end_time
end

function timepoints(ap::LifeAnnuity, ins::Annuity, ::Due)
    # same timepoints as LifeCertain
    end_time = omega(ins.life)
    timestep = 1 / ins.frequency
    return ins.start_time:timestep:end_time
end

function timepoints(ap::TermCertain, ins::Annuity, ::Due)
    end_time = ap.term + ins.start_time - 1 / ins.frequency
    timestep = 1 / ins.frequency
    return ins.start_time:timestep:end_time
end

function timepoints(ap::TermAnnuity, ins::Annuity, ::Due)
    # same timepoints as 
    end_time = ap.term + ins.start_time - 1 / ins.frequency
    timestep = 1 / ins.frequency
    return ins.start_time:timestep:end_time
end

function timepoints(ap::LifeCertain, ins::Annuity, ::Immediate)
    end_time = omega(ins.life)
    timestep = 1 / ins.frequency
    end_time = max(ins.start_time + timestep, end_time) # return at least one timepoint to avoid returning empty array
    return (ins.start_time+timestep):timestep:end_time
end

function timepoints(ap::LifeAnnuity, ins::Annuity, ::Immediate)
    # same timepoints as LifeCertain
    end_time = omega(ins.life)
    timestep = 1 / ins.frequency
    end_time = max(ins.start_time + timestep, end_time) # return at least one timepoint to avoid returning empty array
    return (ins.start_time+timestep):timestep:end_time
end

function timepoints(ap::TermCertain, ins::Annuity, ::Immediate)
    end_time = ap.term + ins.start_time
    timestep = 1 / ins.frequency
    end_time = max(ins.start_time + timestep, end_time) # return at least one timepoint to avoid returning empty array
    return (ins.start_time+timestep):timestep:end_time
end

function timepoints(ap::TermAnnuity, ins::Annuity, ::Immediate)
    # same timepoints as 
    end_time = ap.term + ins.start_time
    timestep = 1 / ins.frequency
    end_time = max(ins.start_time + timestep, end_time) # return at least one timepoint to avoid returning empty array
    return (ins.start_time+timestep):timestep:end_time
end

"""
    present_value(Insurance)

The actuarial present value of the given insurance benefits.
"""
function ActuaryUtilities.present_value(ins::T) where {T<:Insurance}
    cfs = cashflows(ins)
    times = timepoints(ins)
    yield = ins.int
    pv = present_value(yield, cfs, times)
    return pv
end

"""
    present_value(Insurance,`time`)

The actuarial present value of the given insurance benefits, as if you were standing at `time`. 

For example, if the given `Insurance` has *decremented* payments `[1,2,3,4,5]` at times `[1,2,3,4,5]` and you call `pv(ins,3)`, 
you will get the present value of the payments `[4,5]` at times `[1,2]`.

To get an undecremented present value, divide by the survivorship to that timepoint:

```julia
present_value(ins,10) / survival(ins,10)
```
"""
function ActuaryUtilities.present_value(ins::T,time) where {T<:Insurance}
    ts =timepoints(ins)
    times = (t - time for t in ts if t > time)
    cfs = (cf for (cf,t) in zip(cashflows(ins),ts) if t > time)
    yield = ins.int
    pv = present_value(yield, cfs, times)
    return pv
end

"""
    premium_net(lc::LifeContingency)
    premium_net(lc::LifeContingency,to_time)

The net premium for a whole life insurance (without second argument) or a term life insurance through `to_time`.

The net premium is based on 1 unit of insurance with the death benfit payable at the end of the year and assuming annual net premiums.
"""
function premium_net(lc::LifeContingency)
    return A(lc) / ä(lc)
end

premium_net(lc::LifeContingency, to_time) = A(lc, to_time) / ä(lc, to_time)

"""
     reserve_premium_net(lc::LifeContingency,time)

The net premium reserve at the end of year `time`.
"""
function reserve_premium_net(lc::LifeContingency, time)
    PVFB = A(lc) - A(lc, time)
    PVFP = premium_net(lc) * (ä(lc) - ä(lc, time))
    return (PVFB - PVFP) / APV(lc, time)
end

"""
    APV(lc::LifeContingency,to_time)

The **actuarial present value** which is the survival times the discount factor for the life contingency.
"""
function APV(lc::LifeContingency, to_time)
    return survival(lc, to_time) * discount(lc.int, to_time)
end

"""
    decrement(lc::LifeContingency,to_time)
    decrement(lc::LifeContingency,from_time,to_time)

Return the probability of death for the given LifeContingency, with decrements beginning at time zero. 
    
# Examples

```julia-repl
julia> q = [.1,.2,.3,.4];

julia> l = SingleLife(mortality=q);

julia> survival(l,1)
0.9

julia> decrement(l,1)
0.09999999999999998

julia> survival(l,1,2)
0.8

julia> decrement(l,1,2)
0.19999999999999996

julia> survival(l,1,3)
0.5599999999999999

julia> decrement(l,1,3)
0.44000000000000006
```
"""
mt.decrement(lc::LifeContingency, from_time, to_time) = 1 - survival(lc.life, from_time, to_time)


"""
    survival(lc::LifeContingency,from_time,to_time)
    survival(lc::LifeContingency,to_time)

Return the probability of survival for the given LifeContingency, with decrements beginning at time zero. 
    
# Examples

```julia-repl
julia> q = [.1,.2,.3,.4];

julia> l = SingleLife(mortality=q);

julia> survival(l,1)
0.9

julia> decrement(l,1)
0.09999999999999998

julia> survival(l,1,2)
0.8

julia> decrement(l,1,2)
0.19999999999999996

julia> survival(l,1,3)
0.5599999999999999

julia> decrement(l,1,3)
0.44000000000000006
    
    ```
"""
mt.survival(lc::LifeContingency, to_time) = survival(lc.life, 0, to_time)
mt.survival(lc::LifeContingency, from_time, to_time) = survival(lc.life, from_time, to_time)

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
    a = survival(ins,assump,l,from_time)
    b = survival(ins,assump,l,to_time)
    return b/a
end

function mt.survival(ins::LastSurvivor, assump::JointAssumption, l::JointLife, to_time)
    to_time == 0 && return 1.0

    l1, l2 = l.lives
    ₜpₓ = survival(l1.mortality, l1.issue_age, l1.issue_age + to_time, l1.fractional_assump)
    ₜpᵧ = survival(l2.mortality, l2.issue_age, l2.issue_age + to_time, l2.fractional_assump)
    return ₜpₓ + ₜpᵧ - ₜpₓ * ₜpᵧ
end

Yields.discount(lc::LifeContingency, t) = discount(lc.int, t)
Yields.discount(lc::LifeContingency, t1, t2) = discount(lc.int, t1, t2)


# unexported aliases
const V = reserve_premium_net
const v = Yields.discount
# A(args) = present_value(Insurance(args))
# a(args, kwargs) = present_value(AnnuityImmediate(args...; kwargs...))
# ä(args) = present_value(AnnuityDue(args))
const A = present_value ∘ Insurance
const a = present_value ∘ AnnuityImmediate
const ä = present_value ∘ AnnuityDue
const P = premium_net
const ω = omega

end # module
