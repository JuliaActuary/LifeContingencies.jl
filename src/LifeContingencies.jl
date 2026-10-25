module LifeContingencies

using MortalityTables
using FinanceCore
import FinanceCore: present_value, discount

const mt = MortalityTables

include("engine.jl")
include("lives.jl")

export LifeContingency,
    Insurance, AnnuityDue, AnnuityImmediate,
    APV,
    SingleLife, Frasier, JointLife,
    LastSurvivor, FirstToDie,
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

The number of years from issue that the mortality assumption covers: survival to `omega` uses the last defined rate. For parametric mortality, `omega` is `Inf`.

This differs from `omega` of a mortality vector, which is the last attained age with a rate. For example, with issue age 60 and rates through age 100, `omega` of the vector is `100` and `omega` of the life is `41`.
"""
mt.omega(lc::LifeContingency) = omega(lc.life)


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
function l(lc::LifeContingency, to_time; basis=1.0)
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
    FinanceModels.Yield.Constant(0.05),
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
    FinanceModels.Yield.Constant(0.05),
    1, # term of policy
) 
```
"""
function AnnuityDue(life, int, term; certain=nothing, start_time=0, frequency=1)
    term < 1 && return ZeroBenefit(life, int)
    if isnothing(certain)
        Annuity(life, int, Due(), TermAnnuity(term), start_time, frequency)
    else
        Annuity(life, int, Due(), TermCertain(term, certain), start_time, frequency)
    end
end

function AnnuityDue(life, int; certain=nothing, start_time=0, frequency=1)
    if isnothing(certain)
        Annuity(life, int, Due(), LifeAnnuity(), start_time, frequency)
    else
        Annuity(life, int, Due(), LifeCertain(certain), start_time, frequency)
    end
end

function AnnuityDue(lc::L, term; certain=nothing, start_time=0, frequency=1) where {L<:LifeContingency}
    return AnnuityDue(lc.life, lc.int, term; certain, start_time, frequency)
end

function AnnuityDue(lc::L; certain=nothing, start_time=0, frequency=1) where {L<:LifeContingency}
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
    FinanceModels.Yield.Constant(0.05),
    1 # term of policy
) 
```

"""
function AnnuityImmediate(life, int, term; certain=nothing, start_time=0, frequency=1)
    term < 1 && return ZeroBenefit(life, int)
    if isnothing(certain)
        Annuity(life, int, Immediate(), TermAnnuity(term), start_time, frequency)
    else
        Annuity(life, int, Immediate(), TermCertain(term, certain), start_time, frequency)
    end
end

function AnnuityImmediate(life, int; certain=nothing, start_time=0, frequency=1)
    if isnothing(certain)
        Annuity(life, int, Immediate(), LifeAnnuity(), start_time, frequency)
    else
        Annuity(life, int, Immediate(), LifeCertain(certain), start_time, frequency)
    end
end

function AnnuityImmediate(lc::L, term; certain=nothing, start_time=0, frequency=1) where {L<:LifeContingency}
    return AnnuityImmediate(lc.life, lc.int, term; certain, start_time, frequency)
end

function AnnuityImmediate(lc::L; certain=nothing, start_time=0, frequency=1) where {L<:LifeContingency}
    return AnnuityImmediate(lc.life, lc.int; certain, start_time, frequency)
end

"""
    survival(Insurance,time)

The survivorship for the given insurance from time zero to `time`.

"""
function MortalityTables.survival(ins::I, t) where {I<:Insurance}
    survival(ins.life, t)
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
function FinanceCore.discount(ins::I) where {I<:Insurance}
    return Iterators.map(t -> FinanceCore.discount.(ins.int, t), timepoints(ins))
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
function FinanceCore.present_value(ins::T) where {T<:Insurance}
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
function FinanceCore.present_value(ins::T, time) where {T<:Insurance}
    ts = timepoints(ins)
    times = (t - time for t in ts if t > time)
    cfs = (cf for (cf, t) in zip(cashflows(ins), ts) if t > time)
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
mt.survival(lc::LifeContingency, to_time) = survival(lc.life, to_time)
mt.survival(lc::LifeContingency, from_time, to_time) = survival(lc.life, from_time, to_time)

FinanceCore.discount(lc::LifeContingency, t) = discount(lc.int, t)
FinanceCore.discount(lc::LifeContingency, t1, t2) = discount(lc.int, t1, t2)


# unexported aliases
const V = reserve_premium_net
const v = FinanceCore.discount
# A(args) = present_value(Insurance(args))
# a(args, kwargs) = present_value(AnnuityImmediate(args...; kwargs...))
# ä(args) = present_value(AnnuityDue(args))
const A = FinanceCore.present_value ∘ Insurance
const a = FinanceCore.present_value ∘ AnnuityImmediate
const ä = FinanceCore.present_value ∘ AnnuityDue
const P = premium_net
const ω = omega

end # module
