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
    net_premium_annual



include("interest.jl")




# 'actuarial objects' that combine multiple forms of decrements (lapse, interest, death, etc)
abstract type AbstractActuarial end


"""
    struct LifeContingency
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

    LifeContingency(
        mort.select,            # a MortalityTables mortality table
        InterestRate(0.05),     # interest rate
        0                       # issue age
    )
"""
struct LifeContingency
    mort
    int::InterestRate
    issue_age::Int
end


"""
    ω(lc::LifeContingency)

Returns the last defined period for both the interest rate and mortality table.
    In the future, this may only look up the omega of the mortality table.
"""
function ω(lc::LifeContingency)
    # if one of the omegas is infinity, that's a Float so we need
    # to narrow the type with Int
    return Int(min(mt.ω(lc.mort, lc.issue_age), ω(lc.int)))
end

###################
## COMMUTATIONS ###
###################

"""
    D(lc::LifeContingency, duration)

The ``D_x`` actuarial commutation function where the `duration` argument is `x`.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
function D(lc::LifeContingency, duration)
    v(lc.int, duration, 1) * p(lc.mort, lc.issue_age, 1, duration)
end

"""
    l(lc::LifeContingency, duration)

The ``l_x`` actuarial commutation function where the `duration` argument is `x`.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
function l(lc::LifeContingency, duration)
    if duration == 0
        return 1.0
    else
        return p(lc.mort, lc.issue_age, 1, duration)
    end
end

"""
    C(lc::LifeContingency, duration)

The ``C_x`` actuarial commutation function where the `duration` argument is `x`.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
function C(lc::LifeContingency, duration)
    v(lc.int, duration + 1, 1) *
    q(lc.mort, lc.issue_age, duration + 1) *
    l(lc, duration)
end

"""
    N(lc::LifeContingency, duration)

The ``N_x`` actuarial commutation function where the `duration` argument is `x`.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
function N(lc::LifeContingency, duration)
    range = duration:(ω(lc) - lc.issue_age)
    return reduce(+, Map(duration->D(lc, duration)), range)

end

"""
    M(lc::LifeContingency, duration)

The ``M_x`` actuarial commutation function where the `duration` argument is `x`.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
function M(lc::LifeContingency, duration)
    range = duration:(ω(lc) - lc.issue_age)
    return reduce(+, Map(duration->C(lc, duration)), range)
end


E(lc::LifeContingency, t, x) = D(x + t) / D(x)


##################
### Insurances ###
##################

"""
    A(lc::LifeContingency, x, n)

Term insurance for n years for someone starting in the `x`th duration.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
A(lc::LifeContingency, x, n) = (M(lc, x) - M(lc, x + n)) / D(lc, x)

"""
A(lc::LifeContingency, x)
Whole life insurance for someone starting in the `x`th duration.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
A(lc::LifeContingency, x) = M(lc, x) / D(lc, x)

"""
    ä(lc::LifeContingency, x)

Life annuity due for someone starting in the `x`th duration.
Issue age is based on the issue_age in the LifeContingency `lc`.

To enter the `ä` character, type `a` and then `\\ddot`.
    See more on how to [input unicode](https://docs.julialang.org/en/v1/manual/unicode-input/index.html)
    in Julia.

"""
ä(lc::LifeContingency, x) = N(lc, x) / D(lc, x)

"""
    ä(lc::LifeContingency, x,n)

Life annuity due for someone starting in the `x`th duration for `n` years.

To enter the `ä` character, type `a` and then `\\ddot`.
    See more on how to [input unicode](https://docs.julialang.org/en/v1/manual/unicode-input/index.html)
    in Julia.

"""
ä(lc::LifeContingency, x, n) = (N(lc, x) - N(lc, x + n)) / D(lc, x)

"""
    P(lc::LifeContingency,x)

A whole life insurance with 1 unit payable at the end of the year of death,
and payable by net annual premiums, starting from time `x` (often `0`).
"""
P(lc::LifeContingency, x) = A(lc, x) / ä(lc, x)

"""
    V(lc::LifeContingency,t,x=0)

The net premium reserve at the end of year `t`, starting from time `x` (often `0`).
"""
V(lc::LifeContingency, t,x = 0) = A(lc, x + t) - P(lc, x) * ä(lc, x + t)

# aliases
disc = v
reserve_net_premium = V
insurance = A
annuity_due = ä
net_premium_annual = P


end # module
