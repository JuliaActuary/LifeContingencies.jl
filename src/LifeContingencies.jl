module LifeContingencies

using MortalityTables
using Transducers

const mt = MortalityTables

export LifeContingency,
    l,
    InterestRate,
    rate,
    v,
    A,
    ä,
    D,
    M,
    N,
    C,
    P,
    V,
    disc,
    reserve_net_premium,
    insurance,
    annuity_due,
    net_premium_annual,
    q,p,
    SingleLife, Frasier, JointLife,
    LastSurvivor,
    omega, ω



include("interest.jl")




# 'actuarial objects' that combine multiple forms of decrements (lapse, interest, death, etc)
abstract type Life end


"""
    struct SingleLife
        mort
        int::InterestRate
        issue_age::Int
    end

An object containing the necessary assumptions for basic actuarial calculations such
    as commutation functions or life insurance/annuity rates. Issue age is defined so that select 
    mortality rates can be accommodated and so many other calculations need only duration specified.

# Examples
    using MortalityTables
    tbls = MortalityTables.tables()
    mort = tbls["2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB"]

    SingleLife(
        mort.select,            # a MortalityTables mortality table
        InterestRate(0.05),     # interest rate
        0                       # issue age
    )
"""
#TODO UPDATE DOCS 
Base.@kwdef struct SingleLife <: Life
    mort
    issue_age::Int
    alive=true
    fractional_assump = mt.Uniform()
end

abstract type JointAssumption end

struct Frasier <: JointAssumption end

abstract type JointInsurance end

struct LastSurvivor <: JointInsurance end
struct FirstToDie <: JointInsurance end

struct JointLife <: Life
    lives::Tuple{SingleLife,SingleLife}
    insurance::JointInsurance
    joint_assumption::JointAssumption
end

function JointLife(l1::SingleLife, l2::SingleLife,ins::JointInsurance,ja::JointAssumption)
    return JointLife((l1,l2),ins,ja)
end

struct LifeContingency
    life::Life
    int::InterestRate
end


"""
    ω(lc::LifeContingency)

Returns the last defined period for both the interest rate and mortality table.
    In the future, this may only look up the omega of the mortality table.
"""
function mt.ω(lc::LifeContingency)
    # if one of the omegas is infinity, that's a Float so we need
    # to narrow the type with Int
    return Int(min(ω(lc.life), ω(lc.int)))
end

function mt.ω(l::SingleLife)
    return mt.ω(l.mort, l.issue_age)    
end

function mt.ω(l::JointLife)
    return minimum( ω.(l.lives) )    
end

###################
## COMMUTATIONS ###
###################

"""
    D(lc::LifeContingency, time)

The ``D_x`` actuarial commutation function where the `time` argument is `x`.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
function D(lc::LifeContingency, time)
    return D(lc.life,lc,time)
end

function D(::SingleLife,lc::LifeContingency, time)
    v(lc.int, time) * p(lc, 1,time)
end

"""
    l(lc::LifeContingency, time)

The ``l_x`` actuarial commutation function where the `time` argument is `x`.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
function l(lc::LifeContingency, time)
    if time == 0
        return 1.0
    else
        return p(lc.life, 1,time)
    end
end

"""
    C(lc::LifeContingency, duration)

The ``C_x`` actuarial commutation function where the `duration` argument is `x`.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
function C(lc::LifeContingency, duration)
    return C(lc.life,lc,duration)
end

function C(::SingleLife,lc::LifeContingency, duration)
    v(lc.int, duration + 1) *
    mt.q(lc.life, duration + 1) *
    l(lc, duration)
end

"""
    N(lc::LifeContingency, duration)

The ``N_x`` actuarial commutation function where the `duration` argument is `x`.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
function N(lc::LifeContingency, duration)
    return N(lc.life,lc, duration)
end

function N(::SingleLife,lc::LifeContingency, duration)
    range = duration:(ω(lc) - lc.life.issue_age)
    return reduce(+, Map(duration->D(lc, duration)), range)
end

"""
    M(lc::LifeContingency, duration)

The ``M_x`` actuarial commutation function where the `duration` argument is `x`.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
function M(lc::LifeContingency, duration)
    return M(lc.life,lc,duration)
end

function M(::SingleLife,lc::LifeContingency, duration)
    range = duration:(ω(lc) - lc.life.issue_age)
    return reduce(+, Map(duration->C(lc, duration)), range)
end


E(lc::LifeContingency, t, x) = D(lc,x + t) / D(lc,x)


##################
### Insurances ###
##################

"""
    A(lc::LifeContingency, duration, time)

Term insurance for n years for someone starting in the ``x``th `duration`.
Issue age is based on the `issue_age` in the LifeContingency `lc`.
"""
A(lc::LifeContingency, duration, time) = A(lc.life,lc,duration,time)
function A(::SingleLife,lc::LifeContingency, duration, time) 
    return (M(lc, duration) - M(lc, duration + time)) / D(lc, duration)
end

"""
    A(lc::LifeContingency, duration)

Whole life insurance for someone starting in the ``x``th `duration`.
Issue age is based on the `issue_age` in the LifeContingency `lc`.
"""
A(lc::LifeContingency, duration) = A(lc.life,lc,duration)
A(::SingleLife,lc::LifeContingency, duration) = M(lc, duration) / D(lc, duration)

"""
    ä(lc::LifeContingency, duration)

Life annuity due for someone starting in the their ``x``th `duration`.
Issue age is based on the `issue_age` in the LifeContingency `lc`.

To enter the `ä` character, type `a` and then `\\ddot`.
    See more on how to [input unicode](https://docs.julialang.org/en/v1/manual/unicode-input/index.html)
    in Julia.

"""
ä(lc::LifeContingency, duration) = ä(lc.life,lc, duration)
ä(::SingleLife,lc::LifeContingency, duration) = N(lc, duration) / D(lc, duration)

"""
    ä(lc::LifeContingency, duration,time)

Life annuity due for someone starting in the `x`th `duration` for `time` years.

To enter the `ä` character, type `a` and then `\\ddot`.
    See more on how to [input unicode](https://docs.julialang.org/en/v1/manual/unicode-input/index.html)
    in Julia.

"""
ä(lc::LifeContingency, duration, time) = ä(lc.life,lc, duration, time)

function ä(::SingleLife, lc::LifeContingency, duration, time) 
    return (N(lc, duration) - N(lc, duration + time)) / D(lc, duration)
end

"""
    P(lc::LifeContingency,start_time=0)

A whole life insurance with 1 unit payable at the end of the year of death,
and payable by net annual premiums, starting from `start_time` timepoint (often `0`).
"""
P(lc::LifeContingency, start_time=0) = A(lc, start_time) / ä(lc, start_time)

"""
    V(lc::LifeContingency,t,start_time=0)

The net premium reserve at the end of year `t`, starting from time `start_time` (often `0`).
"""
function V(lc::LifeContingency, t,start_time = 0) 
    return A(lc, start_time + t) - P(lc, start_time) * ä(lc, start_time + t)
end

"""
    q(lc::LifeContingency,duration,time=1)
    q(lc::LifeContingency,duration,time=1)

Return the probablity of death for the given LifeContingency. 
"""
mt.q(lc::LifeContingency,duration,time=1) = q(lc.life,lc,duration,time)

mt.q(::SingleLife,lc::LifeContingency,duration,time) = q(lc.life,duration,time)

mt.q(l::SingleLife,duration,time) = q(l.mort,l.issue_age,duration,time)
mt.q(l::SingleLife,duration) = q(l.mort,l.issue_age,duration,1)

function mt.q(l::JointLife,duration,time) 
    return 1 - p(l,duration,time) 
end
function mt.q(l::JointLife,duration) 
    return 1 -  p(l::JointLife,1,duration) / p(l::JointLife,1,duration-1)
end

"""
    p(lc::LifeContingency,duration,time=1)
    p(lc::LifeContingency,duration)

Return the probablity of survival for the given LifeContingency. 
"""
mt.p(lc::LifeContingency,duration,time=1) = p(lc.life, lc, duration, time)

mt.p(::SingleLife,lc::LifeContingency,duration,time) = p(lc.life,duration,time)

mt.p(l::SingleLife,duration,time) = p(l.mort,l.issue_age,duration,time)
mt.p(l::SingleLife,duration) = p(l.mort,l.issue_age,1,1)

function mt.p(l::JointLife,duration,time)
    return mt.p(l.insurance,l.joint_assumption,l,duration,time)
end
function mt.p(ins::LastSurvivor,assump::JointAssumption,l::JointLife,duration,time)
    l1,l2 = l.lives
    ₜpₓ = time == 0 ? 1.0 : p(l1.mort,l1.issue_age,duration,time,l1.fractional_assump)
    ₜpᵧ = time == 0 ? 1.0 : p(l2.mort,l2.issue_age,duration,time,l2.fractional_assump)
    return ₜpₓ + ₜpᵧ - ₜpₓ * ₜpᵧ
end

# because the cumulative effect of the unknown life statuses,
# we always assume that the calculations are from the issue age
# which is a little bit different from the single life, where
# indexing starting in a future duration is okay because there's not a 
# conditional on another life. Here we have to use the whole surivaval
# stream to calculate a mortality at a given point
function mt.p(l::JointLife,duration)
    if duration == 0
        return 1.0
    else
        return   1 - q(l,duration)
    end
end

# aliases
disc = v
reserve_net_premium = V
insurance = A
annuity_due = ä
net_premium_annual = P
omega(x) = ω(x)

end # module
