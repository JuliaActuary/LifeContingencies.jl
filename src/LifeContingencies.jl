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
        mort
        issue_age::Int
        alive::Bool
        fractional_assump::MortalityTables.DeathDistribution
    end

A `Life` object containing the necessary assumptions for contingent maths related to a single life. Use with a `LifeContingency` to do many actuarial present value calculations. 

Keyword arguments:
- `mort` pass a mortality vector, which is an array of applicable mortality rates indexed by attained age
- `issue_age` is the assumed issue age for the `SingleLife` and is the basis of many contingency calculations.
- `alive` Default value is `true`. Useful for joint insurances with different status on the lives insured.
- `fractional_assump`. Default value is `Uniform()`. This is a `DeathDistribution` from the `MortalityTables.jl` package and is the assumption to use for non-integer ages/times.

# Examples
    using MortalityTables
    tbls = MortalityTables.tables()
    mort = tbls["2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB"]

    SingleLife(
        mort       = mort.select[30], 
        issue_age  = 30          
    )
"""
Base.@kwdef struct SingleLife <: Life
    mort
    issue_age::Int
    alive=true
    fractional_assump = mt.Uniform()
end

""" 
    JointAssumption()

An abstract type representing the different assumed relationship between the survival of the lives on a JointLife. Available options to use include:
- `Frasier()`
"""
abstract type JointAssumption end

""" 
    Frasier()

The assumption of independnt lives in a joint life calculation.
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
    tbls = MortalityTables.tables()
    mort = tbls["2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB"]

    l1 = SingleLife(
        mort       = mort.select[30], 
        issue_age  = 30          
    )
    l2 = SingleLife(
        mort       = mort.select[30], 
        issue_age  = 30          
    )

    jl = JointLife(
        lives = (l1,l2),
        contingency = LastSurvivor(),
        joint_assumption = Frasier()
    )
"""
Base.@kwdef struct JointLife <: Life
    lives::Tuple{SingleLife,SingleLife}
    contingency::Contingency = LastSurvivor()
    joint_assumption::JointAssumption = Frasier()
end

"""
    struct LifeContingency
        life::Life
"""
struct LifeContingency
    life::Life
    int
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
    return mt.omega(l.mort) - l.issue_age + 1    
end

function mt.omega(l::JointLife)
    return minimum( omega.(l.lives) )    
end


###################
## COMMUTATIONS ###
###################

"""
    D(lc::LifeContingency, to_time)

``D_x`` is a retrospective actuarial commutation function which is the product of the survival and discount factor.
"""
function D(lc::LifeContingency, to_time)
    return discount(lc.int, to_time) * survival(lc,to_time)
end


"""
    l(lc::LifeContingency, to_time)

``l_x`` is a retrospective actuarial commutation function which is the survival up to a certain point in time. By default, will have a unitary basis (ie `1.0`), but you can specify `basis` keyword argument to use something different (e.g. `1000` is common in the literature.)
"""
function l(lc::LifeContingency, to_time; basis=1.0)
    return survival(lc.life,to_time) * basis
end

"""
    C(lc::LifeContingency, to_time)

``C_x`` is a retrospective actuarial commutation function which is the product of the discount factor and the difference in `l` (``l_x``).
"""
function C(lc::LifeContingency, to_time)
    discount(lc.int, to_time+1) * (l(lc,to_time) - l(lc, to_time+1))
    
end

"""
    N(lc::LifeContingency, from_time)

``N_x`` is a prospective actuarial commutation function which is the sum of the `D` (``D_x``) values from the given time to the end of the mortality table.
"""
function N(lc::LifeContingency, from_time)
    range = from_time:(omega(lc)-1)
    return foldxt(+,Map(from_time->D(lc, from_time)), range)
end

"""
    M(lc::LifeContingency, from_time)

The ``M_x`` actuarial commutation function where the `from_time` argument is `x`.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
function M(lc::LifeContingency, from_time)
    range = from_time:omega(lc)-1
    return foldxt(+,Map(from_time->C(lc, from_time)), range)
end

E(lc::LifeContingency, t, x) = D(lc,x + t) / D(lc,x)


##################
### Insurances ###
##################

abstract type Insurance end

struct WholeLife <: Insurance
    life
    int
end

struct Term <: Insurance
    life
    int
    n
end

"""
    Insurance(lc::LifeContingency; n=nothing)
    Insurance(life,interest; n=nothing)

Life insurance with a term period of `n`. If `n` is `nothing`, then whole life insurance.

Issue age is based on the `issue_age` in the LifeContingency `lc`.

# Examples

```
ins = Insurance(
    SingleLife(mort = UltimateMortality([0.5,0.5]),issue_age = 0),
    Yields.Constant(0.05),
    n = 1
) 
```
"""
Insurance(lc::LifeContingency; n=nothing) = Insurance(lc.life,lc.int;n)

function Insurance(lc,int;n=nothing)
    if isnothing(n)
        return WholeLife(lc,int)
    elseif n < 1
        return ZeroBenefit(lc,int)
    else
        Term(lc,int,n)
    end
end

struct Due end
struct Immediate end

struct Annuity <: Insurance
    life
    int
    payable
    n
    start_time
    certain
    frequency
end

struct ZeroBenefit <: Insurance
    life
    int
end

function ZeroBenefit(lc::LifeContingency) 
    return ZeroBenefit(lc.life,lc.int)
end

"""
    AnnuityDue(lc::LifeContingency; n=nothing, start_time=0; certain=nothing,frequency=1)
    AnnuityDue(life, interest; n=nothing, start_time=0; certain=nothing,frequency=1)

Annuity due with the benefit period starting at `start_time` and ending after `n` periods with `frequency` payments per year of `1/frequency` amount and a `certain` period with non-contingent payments. 

# Examples

```
ins = AnnuityDue(
    SingleLife(mort = UltimateMortality([0.5,0.5]),issue_age = 0),
    Yields.Constant(0.05),
    n = 1
) 
```

"""
function AnnuityDue(life, int; n=nothing,start_time=0,certain=nothing,frequency=1) 
    if ~isnothing(n) && n < 1
        return ZeroBenefit(life,int)
    else
        Annuity(life,int,Due(),n,start_time,certain,frequency)
    end
end

function AnnuityDue(lc::LifeContingency; n=nothing,start_time=0,certain=nothing,frequency=1) 
    return AnnuityDue(lc.life,lc.int;n,start_time,certain,frequency)
end


"""
    AnnuityImmediate(lc::LifeContingency; n=nothing, start_time=0; certain=nothing,frequency=1)
    AnnuityImmediate(life, interest; n=nothing, start_time=0; certain=nothing,frequency=1)

Annuity immediate with the benefit period starting at `start_time` and ending after `n` periods with `frequency` payments per year of `1/frequency` amount and a `certain` period with non-contingent payments. 

# Examples

```
ins = AnnuityImmediate(
    SingleLife(mort = UltimateMortality([0.5,0.5]),issue_age = 0),
    Yields.Constant(0.05),
    n = 1
) 
```

"""
function AnnuityImmediate(life, int; n=nothing,start_time=0,certain=nothing,frequency=1) 
    if ~isnothing(n) && n < 1
        return ZeroBenefit(life,int)
    else
        return Annuity(life,int,Immediate(),n,start_time,certain,frequency)
    end
end

function AnnuityImmediate(lc::LifeContingency; n=nothing,start_time=0,certain=nothing,frequency=1)  
    return AnnuityImmediate(lc.life,lc.int;n,start_time,certain,frequency)
end


"""
    survival(Insurance)

The survorship vector for the given insurance.
"""
function MortalityTables.survival(ins::Insurance)
    return [survival(ins.life,t-1) for t in timepoints(ins)]
end

function MortalityTables.survival(ins::Annuity)
    return [survival(ins.life,t) for t in timepoints(ins)]
end


"""
    discount(Insurance)

The discount vector for the given insurance.
"""
function Yields.discount(ins::Insurance)
    return Yields.discount.(ins.int,timepoints(ins))
end


"""
    benefit(Insurance)

The unit benefit vector for the given insurance.
"""
function benefit(ins::Insurance)
    return ones(length(timepoints(ins)))
end

function benefit(ins::ZeroBenefit)
    return zeros(length(timepoints(ins)))
end

function benefit(ins::Annuity)
    return ones(length(timepoints(ins))) ./ ins.frequency
end


"""
    survival(Insurance)

The vector of contingent benefit probabilities for the given insurance.
"""
function probability(ins::Insurance)
    return [survival(ins.life,t-1) * decrement(ins.life,t-1,t) for t in timepoints(ins)]
end

function probability(ins::ZeroBenefit)
    return ones(length(timepoints(ins)))
end

function probability(ins::Annuity)
    if isnothing(ins.certain)
        return  [survival(ins.life,t) for t in timepoints(ins)]
    else
        return [t <= ins.certain + ins.start_time ? 1.0 : survival(ins.life,t) for t in timepoints(ins)]
    end
end


"""
    cashflows(Insurance)

The vector of decremented benefit cashflows for the given insurance.
"""
function cashflows(ins::Insurance)
   return probability(ins) .* benefit(ins)
end


"""
    timepoints(Insurance)

The vector of times corresponding to the cashflow vector for the given insurance.
"""
function timepoints(ins::Insurance)
    return collect(1:omega(ins.life))
end

function timepoints(ins::Term)
    return collect(1:min(omega(ins.life),ins.n))
end

function timepoints(ins::ZeroBenefit)
    return [0.]
end

function timepoints(ins::Annuity)
    return timepoints(ins,ins.payable)
end

function timepoints(ins::Annuity,payable::Due)
    if isnothing(ins.n)
        end_time = omega(ins.life)
    else
        end_time = ins.n + ins.start_time - 1 / ins.frequency
    end
    timestep = 1 / ins.frequency
    collect(ins.start_time:timestep:end_time)
end

function timepoints(ins::Annuity,payable::Immediate)
    if isnothing(ins.n)
        end_time = omega(ins.life)
    else
        end_time = ins.n + ins.start_time
    end
    timestep = 1 / ins.frequency
    end_time = max(ins.start_time + timestep,end_time) # return at least one timepoint to avoid returning empty array
    collect((ins.start_time + timestep):timestep:end_time)
end

"""
    present_value(Insurance)

The actuarial present value of the given insurance.
"""
function ActuaryUtilities.present_value(ins)
    return present_value(ins.int,cashflows(ins),timepoints(ins))
end

"""
    insurance(lc::LifeContingency,from_time=0,to_time=nothing)

Life insurance for someone starting at `from_time` and lasting until `to_time`. If `to_time` is `nothing` (the default), will be insurance until the end of the mortality table or interest rates.

Issue age is based on the `issue_age` in the LifeContingency `lc`.
"""
insurance(lc::LifeContingency,to_time=nothing) = insurance(lc.life,lc,to_time)

function insurance(::SingleLife,lc::LifeContingency,to_time)
    iszero(to_time) && return 0.0 #short circuit and return 0 if there is no time elapsed
    mt = lc.life.mort
    iss_age = lc.life.issue_age
    end_age = to_time + iss_age -1
    len = end_age - iss_age
    v = discount.(lc.int,1:len+1)
    tpx =  [survival(mt,iss_age,att_age, lc.life.fractional_assump) for att_age in iss_age:end_age]
    qx =   mt[iss_age:end_age]

    sum(v .* tpx  .* qx)
end

function insurance(::SingleLife,lc::LifeContingency,::Nothing)
    mt = lc.life.mort
    iss_age = lc.life.issue_age
    end_age = omega(lc) + iss_age - 1
    len = end_age - iss_age
    v = discount.(lc.int,1:len+1)
    tpx =  [survival(mt,iss_age,att_age, lc.life.fractional_assump) for att_age in iss_age:end_age]
    qx =   mt[iss_age:end_age]

    sum(v .* tpx  .* qx)
end

# for joint, dispactch based on the type of insruance and assumption
function insurance(::JointLife,lc::LifeContingency, to_time) 
    insurance(lc.life.contingency, lc.life.joint_assumption,lc,to_time)
end

function insurance(::LastSurvivor,::Frasier,lc::LifeContingency, to_time)
    iszero(to_time) && return 0.0 #short circuit and return 0 if there is no time elapsed
    v = discount.(lc.int,1:to_time)
    tpx =  [survival(lc,t) for t in 0:to_time-1]
    qx =   [ survival(lc,t) - survival(lc,t+1) for t in 0:to_time-1]

    sum(v .* tpx  .* qx)
end

function insurance(::LastSurvivor,::Frasier,lc::LifeContingency, ::Nothing)
    to_time = omega(lc)
    v = discount.(lc.int,1:to_time)
    tpx =  [survival(lc,t) for t in 0:to_time-1]
    qx =   [ survival(lc,t) - survival(lc,t+1) for t in 0:to_time-1]

    sum(v .* tpx  .* qx)
end

"""
    annuity_due(lc::LifeContingency, n,start_time=0,certain=nothing,frequency=1)
    annuity_due(lc::LifeContingency,start_time=0,certain=nothing,frequency=1)

Life annuity due for the life contingency `lc` with the benefit period starting at `start_time` and ending after `n` periods with `frequency` payments per year of `1/frequency` amount. 
    
If `n` is omitted, will return whole life annuity due. 

`certain` is the length of the certain time (which begins at `start_time`). 

# Extended help

To enter the `annuity_due` character, type `a` and then `\\ddot`.
    See more on how to [input unicode](https://docs.julialang.org/en/v1/manual/unicode-input/index.html)
    in Julia.

"""
function annuity_due(lc::LifeContingency; start_time=0, certain=nothing, frequency=1) 
    return annuity_due(lc.life,lc,start_time=start_time,certain=certain,frequency=frequency)
end

function annuity_due(lc::LifeContingency,n; start_time=0, certain=nothing,frequency=1) 
    return annuity_due(lc.life,lc,n,start_time=start_time,certain=certain,frequency=frequency)
end

function annuity_due(::SingleLife,lc::LifeContingency, n; start_time=0, certain=nothing,frequency=1)
    n -=  start_time
    n == 0 && return 0.0 # break and return if no payments to be made
    end_time = n + start_time - 1 / frequency
    timestep = 1 / frequency
    discount_factor = discount.(lc.int,start_time:timestep:end_time)

    if isnothing(certain)
        pmts = [survival(lc,t) for t in start_time:timestep:end_time] ./ frequency
    else
        pmts = [t <= certain + start_time ? 1. : survival(lc,t) for t in start_time:timestep:end_time] ./ frequency
    end

    return sum(discount_factor .* pmts)
end

function annuity_due(::SingleLife,lc::LifeContingency; start_time=0, certain=nothing,frequency=frequency)
    n = omega(lc) - start_time
    end_time = (n+start_time)
    timestep = 1 / frequency
    discount_factor = discount.(lc.int,start_time:timestep:end_time)
    if isnothing(certain)
        pmts = [survival(lc,t) for t in start_time:timestep:end_time] ./ frequency
    else
        pmts = [t <= certain + start_time ? 1. : survival(lc,t) for t in start_time:timestep:end_time] ./ frequency
    end

    return sum(discount_factor .* pmts)
end

# for joint, dispactch based on the type of insruance and assumption
function annuity_due(::JointLife,lc::LifeContingency;start_time=0, certain=nothing,frequency=1) 
    return ä(lc.life.contingency,lc.life.joint_assumption,lc,start_time=start_time,certain=certain,frequency=frequency)
end

function annuity_due(::JointLife,lc::LifeContingency, n;start_time=0, certain=nothing,frequency=1) 
    return ä(lc.life.contingency,lc.life.joint_assumption,lc,n,start_time=start_time,certain=certain,frequency=frequency)
end

function annuity_due(::LastSurvivor,::Frasier, lc::LifeContingency, n;start_time=0, certain=nothing,frequency=1)
    n -=  start_time
    n == 0 && return 0.0
    end_time = n + start_time - 1 / frequency
    timestep = 1 / frequency
    discount_factor = discount.(lc.int,start_time:timestep:end_time)
    if isnothing(certain)
        pmts = [survival(lc,t) for t in start_time:timestep:end_time] ./ frequency
    else
        pmts = [t <= certain + start_time ? 1. : survival(lc,t) for t in start_time:timestep:end_time] ./ frequency
    end
    return sum( discount_factor .* pmts )

end

function annuity_due(::LastSurvivor,::Frasier, lc::LifeContingency;start_time=0, certain=nothing,frequency=1)
    n = omega(lc) - start_time
    end_time = n + start_time
    timestep = 1 / frequency
    discount_factor = discount.(lc.int,start_time:timestep:end_time)
    if isnothing(certain)
        pmts = [survival(lc,t) for t in start_time:timestep:end_time] ./ frequency
    else
        pmts = [t <= certain + start_time ? 1. : survival(lc,t) for t in start_time:timestep:end_time] ./ frequency
    end
    return sum( discount_factor .* pmts )

end

"""
    annuity_immediate(lc::LifeContingency, n; start_time=0; certain=nothing,frequency=1)
    annuity_immediate(lc::LifeContingency; start_time=0,certain=nothing,frequency=1)

Life annuity immediate for the life contingency `lc` with the benefit period starting at `start_time` and ending after `n` periods with `frequency` payments per year of `1/frequency` amount. 
    
If `n` is omitted, will calculate the whole life immediate annuity. `certain` is the length of the certain time (which begins at `start_time`).
"""
function annuity_immediate(lc::LifeContingency;start_time=0, certain=nothing,frequency=1) 
   return annuity_due(lc,start_time=start_time,certain=certain,frequency=frequency) - 1 / frequency  # eq 5.11 ALMCR 2nd ed
end

# eq 5.13 ALMCR 2nd ed
function annuity_immediate(lc::LifeContingency,n; start_time=0,certain=nothing,frequency=1) 
    x = annuity_due(lc,n;start_time=start_time,certain=certain,frequency=frequency)
    return x - 1/frequency * (1 - APV(lc,n)) # ALMCR 5.23                               
end



"""
    premium_net(lc::LifeContingency)
    premium_net(lc::LifeContingency,to_time)

The net premium for a whole life insurance (without second argument) or a term life insurance through `to_time`.

The net premium is based on 1 unit of insurance with the death benfit payable at the end of the year and assuming annual net premiums.
"""
premium_net(lc::LifeContingency) = insurance(lc) / ä(lc)
premium_net(lc::LifeContingency,to_time) = insurance(lc,to_time) / ä(lc,to_time)

"""
     reserve_premium_net(lc::LifeContingency,time)

The net premium reserve at the end of year `time`.
"""
function  reserve_premium_net(lc::LifeContingency, time) 
    PVFB = insurance(lc) - insurance(lc,time)
    PVFP = premium_net(lc) * (ä(lc) - ä(lc,time))
    return (PVFB - PVFP) / APV(lc,time)
end

"""
    APV(lc::LifeContingency,to_time)

The **actuarial present value** which is the survival times the discount factor for the life contingency.
"""
function APV(lc::LifeContingency,to_time)
    return survival(lc,to_time) * discount(lc.int,to_time)
end

"""
    decrement(lc::LifeContingency,to_time)
    decrement(lc::LifeContingency,from_time,to_time)

Return the probablity of death for the given LifeContingency. 
"""
mt.decrement(lc::LifeContingency,from_time,to_time) = 1 - survival(lc.life,from_time,to_time)


"""
    survival(lc::LifeContingency,from_time,to_time)
    survival(lc::LifeContingency,to_time)

Return the probablity of survival for the given LifeContingency. 
"""
mt.survival(lc::LifeContingency,to_time) = survival(lc.life, 0, to_time)
mt.survival(lc::LifeContingency,from_time,to_time) = survival(lc.life, from_time, to_time)

mt.survival(l::SingleLife,to_time) = survival(l,0,to_time)
mt.survival(l::SingleLife,from_time,to_time) = survival(l.mort,l.issue_age + from_time,l.issue_age + to_time, l.fractional_assump)

mt.survival(l::JointLife,to_time) = survival(l::JointLife,0,to_time)
function mt.survival(l::JointLife,from_time,to_time) 
    return survival(l.contingency,l.joint_assumption,l::JointLife,from_time,to_time)
end

function mt.survival(ins::LastSurvivor,assump::JointAssumption,l::JointLife,from_time,to_time)
    to_time == 0 && return 1.0
    
    l1,l2 = l.lives
    ₜpₓ = survival(l1.mort,l1.issue_age + from_time,l1.issue_age + to_time,l1.fractional_assump)
    ₜpᵧ = survival(l2.mort,l2.issue_age + from_time,l2.issue_age + to_time,l2.fractional_assump)
    return ₜpₓ + ₜpᵧ - ₜpₓ * ₜpᵧ
end

Yields.discount(lc::LifeContingency,t) = discount(lc.int,t)
Yields.discount(lc::LifeContingency,t1,t2) = discount(lc.int,t1,t2)

# unexported aliases
const V = reserve_premium_net
const v = Yields.discount
const A = insurance
const a = annuity_immediate
const ä = annuity_due
const P = premium_net
const ω = omega

end # module
