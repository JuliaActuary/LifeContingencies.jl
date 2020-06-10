module LifeContingencies

using MortalityTables
using Transducers
using Dates
using IterTools
using QuadGK

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
    decrements,
    reserve_net_premium,
    insurance,
    annuity_due,
    net_premium_annual,
    q,p,
    SingleLife, Frasier, JointLife,
    LastSurvivor,
    omega, ω,
    DiscountFactor



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

abstract type Contingency end

struct LastSurvivor <: Contingency end
struct FirstToDie <: Contingency end

struct JointLife <: Life
    lives::Tuple{SingleLife,SingleLife}
    contingency::Contingency
    joint_assumption::JointAssumption
end

function JointLife(l1::SingleLife, l2::SingleLife,ins::Contingency,ja::JointAssumption)
    return JointLife((l1,l2),ins,ja)
end

struct LifeContingency
    life::Life
    int::InterestRate
end
Base.broadcastable(lc::LifeContingency) = Ref(lc)

decrements(lc::LifeContingency) = decrements(lc.life)
decrements(lc::SingleLife) = (death = lc.mort,)
decrements(lc::JointLife) = (death = [lc.life[1].mort,lc.life[2].mort],)

function Base.iterate(lc::LifeContingency)
    #TODO calcualte the decrments here in an iterative fashion rather than calling out to 
    # `survivorship`
    @show decs = decrements(lc)

    @show f, r = firstrest(zip(decrements(lc)...))
    return (
        ( # current value
            time=0,
            suvivorship=1.0,
            cumulative_decrement=0.0,
            decrements=f,
        ), 
        ( # state
            time=1,
            survivorship = 1.0 * survivorship(lc,1),
            cumulative_decrement = 1 - survivorship(lc,1),
            decrements_tail=r,
        ) 
    )
end


# function Base.iterate(lc::LifeContingency,state)
#     #TODO calcualte the decrments here in an iterative fashion rather than calling out to 
#     # `survivorship`
#     IterTools.@ifsomething state.decrements_tail
#         return nothing
#     else
#         f, r = firstrest(state.decrements_tail)
#         next_time = state.time + 1
#         return (
#                 state, # current value
#             ( # state
#                 time=next_time,
#                 survivorship = state.survivorship * survivorship(lc,state.time,next_time),
#                 cumulative_decrement = 1 - survivorship(lc,state.time,next_time),
#                 decrements_tail=r,
#             ) 
#         )
#     end
# end

function Base.IteratorSize(::Type{<:LifeContingency})
    return Base.HasLength()
end

Base.length(lc::LifeContingency) = length(zip(decrements(lc)))

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
    return mt.ω(l.mort)    
end

function mt.ω(l::JointLife)
    return minimum( ω.(l.lives) )    
end

###################
## COMMUTATIONS ###
###################

"""
    D(lc::LifeContingency, to_time)

``D_x`` is a retrospective actuarial commutation function which is the product of the survivorship and discount factor.
"""
function D(lc::LifeContingency, to_time)
    return v(lc.int, to_time) * survivorship(lc,to_time)
end


struct DIter
    lc
end

"""
    l(lc::LifeContingency, to_time)

``l_x`` is a retrospective actuarial commutation function which is the survivorship up to a certain point in time. By default, will have a unitary basis (ie `1.0`), but you can specify `basis` keyword argument to use something different (e.g. `1000` is common in the literature.)
"""
function l(lc::LifeContingency, to_time; basis=1.0)
    return survivorship(lc.life,to_time) * basis
end

"""
    C(lc::LifeContingency, to_time)

``C_x`` is a retrospective actuarial commutation function which is the product of the discount factor and the difference in `l` (``l_x``).
"""
function C(lc::LifeContingency, to_time)
    v(lc.int, to_time) * (l(lc,to_time + 1) - l(lc, to_time))
    
end

"""
    N(lc::LifeContingency, from_time)

``N_x`` is a prospective actuarial commutation function which is the sum of the `D` (``D_x``) values from the given time to the end of the mortality table.
"""
function N(lc::LifeContingency, from_time)
    return reduce(+,)
    return N(lc.life,lc, from_time)
end

function N(::SingleLife,lc::LifeContingency, from_time)
    range = from_time:(ω(lc) - lc.life.issue_age)
    return reduce(+, Map(from_time->D(lc, from_time)), range)
end

"""
    M(lc::LifeContingency, from_time)

The ``M_x`` actuarial commutation function where the `from_time` argument is `x`.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
function M(lc::LifeContingency, from_time)
    return M(lc.life,lc,from_time)
end

function M(::SingleLife,lc::LifeContingency, from_time)
    range = from_time:(ω(lc) - lc.life.issue_age)
    return reduce(+, Map(from_time->C(lc, from_time)), range)
end


E(lc::LifeContingency, t, x) = D(lc,x + t) / D(lc,x)


##################
### Insurances ###
##################

   
"""
    A(lc::LifeContingency,from_time=0,to_time=nothing)

Life insurance for someone starting at `from_time` and lasting until `to_time`. If `to_time` is `nothing` (the default), will be insurance until the end of the mortality table or interest rates.

Issue age is based on the `issue_age` in the LifeContingency `lc`.
"""
A(lc::LifeContingency,from_time=0,to_time=nothing) = A(lc.life,lc,from_time,to_time)
function A(::SingleLife,lc::LifeContingency, from_time,to_time)
    mt = lc.life.mort
    iss_age = lc.life.issue_age
    start_age = iss_age + from_time
    end_age = isnothing(to_time) ? omega(lc) : to_time + iss_age + start_age
    len = end_age - start_age
    disc = v.(lc.int,1:len)
    tpx =  [p(mt,iss_age,1 + start_age - lc.life.issue_age,   t,lc.life.fractional_assump) for t in 0:(len-1)]
    qx = [q(mt,iss_age,1 + start_age - lc.life.issue_age + t ,1,lc.life.fractional_assump) for t in 0:(len-1)]   
    reduce(+, disc .* tpx  .* qx)
end

# for joint, dispactch based on the type of insruance and assumption
function A(::JointLife,lc::LifeContingency, from_time=0, to_time=nothing) 
    A(lc.life.contingency, lc.life.joint_assumption,lc,from_time,to_time)
end

function A(::LastSurvivor,::Frasier,lc::LifeContingency,from_time=0, to_time=nothing)
    l1 = LifeContingency(lc.life.lives[1],lc.int)
    l2 = LifeContingency(lc.life.lives[2],lc.int)
    A₁ = A(l1,from_time,to_time)
    A₂ = A(l2,from_time,to_time)
    return  A₁ + A₂ - A₁ * A₂
end

"""
    ä(lc::LifeContingency, from_time=0,to_time=nothing)

Life annuity due for the life contingency `lc` with the benefit period starting at `from_time` and ending at `to_time`. If `to_time` is `nothing`, will be benefit until the end of the mortality table or interest rates.
Issue age is based on the `issue_age` in the LifeContingency `lc`.

Issue age is based on the `issue_age` in the LifeContingency `lc`.

To enter the `ä` character, type `a` and then `\\ddot`.
    See more on how to [input unicode](https://docs.julialang.org/en/v1/manual/unicode-input/index.html)
    in Julia.

"""
ä(lc::LifeContingency, from_time=0,to_time=nothing) = ä(lc.life,lc, from_time,to_time)

function ä(::SingleLife,lc::LifeContingency, from_time=0,to_time=nothing) 
    to_time = isnothing(to_time) ? omega(lc) - lc.life.issue_age : to_time
    (N(lc, from_time) - N(lc,to_time)) / (D(lc, from_time) - D(lc,to_time)) 
end

# for joint, dispactch based on the type of insruance and assumption
function ä(::JointLife,lc::LifeContingency, from_time=1, to_time=nothing) 
    ä(lc.life.contingency,lc.life.joint_assumption,lc,from_time,to_time)
end

function ä(::LastSurvivor,::Frasier, lc::LifeContingency, from_time, to_time)
    to_time = isnothing(to_time) ? omega(lc) - lc.life.issue_age : to_time
    return sum( v(lc.int,t,1) * p(lc,1,t) for t in from_time:(to_time-1))
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
    cumulative_decrement(lc::LifeContingency,to_time)
    cumulative_decrement(lc::LifeContingency,from_time,to_time)

Return the probablity of death for the given LifeContingency. 
"""
mt.cumulative_decrement(lc::LifeContingency,from_time,to_time) = 1 - survivorship(lc.life,from_time,to_time)

# mt.cumulative_decrement(l::SingleLife,from_time) = 1 - survivorship(l,from_time)
# mt.cumulative_decrement(l::SingleLife,from_time,to_time) = 1 - survivorship(l,from_time,to_time)

# mt.cumulative_decrement(l::JointLife,from_time) = 1 - survivorship(l,from_time) 
# mt.cumulative_decrement(l::JointLife,from_time,to_time) = 1 - survivorship(l,from_time,to_time) 

"""
    survivorship(lc::LifeContingency,from_time,to_time)
    survivorship(lc::LifeContingency,to_time)

Return the probablity of survival for the given LifeContingency. 
"""
mt.survivorship(lc::LifeContingency,to_time) = survivorship(lc.life, 0, to_time)
mt.survivorship(lc::LifeContingency,from_time,to_time) = survivorship(lc.life, from_time, to_time)

mt.survivorship(l::SingleLife,to_time) = survivorship(l,0,to_time)
mt.survivorship(l::SingleLife,from_time,to_time) = survivorship(l.mort,l.issue_age + from_time,l.issue_age + to_time)

function mt.survivorship(l::JointLife,duration,time)
    return mt.survivorship(l.contingency,l.joint_assumption,l,duration,time)
end

function mt.survivorship(ins::LastSurvivor,assump::JointAssumption,l::JointLife,from_time,to_time)
    l1,l2 = l.lives
    ₜpₓ = time == 0 ? 1.0 : survivorship(l1.mort,l1.issue_age + from_time,to_time,l1.fractional_assump)
    ₜpᵧ = time == 0 ? 1.0 : survivorship(l2.mort,l2.issue_age + from_time,to_time,l2.fractional_assump)
    return ₜpₓ + ₜpᵧ - ₜpₓ * ₜpᵧ
end

# because the cumulative effect of the unknown life statuses,
# we always assume that the calculations are from the issue age
# which is a little bit different from the single life, where
# indexing starting in a future duration is okay because there's not a 
# conditional on another life. Here we have to use the whole surivaval
# stream to calculate a mortality at a given point
function mt.survivorship(l::JointLife,duration)
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
