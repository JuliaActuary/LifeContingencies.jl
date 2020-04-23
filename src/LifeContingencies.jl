module LifeContingencies
using MortalityTables
using Transducers

const mt = MortalityTables

export LifeContingency,
    qx,
    px,
    tpx,
    tqx,
    tqxy,
    tpxy,
    tqx̅y̅,
    tpx̅y̅,
    lx,
    dx,
    ex,
    ixVector,
    InterestRate,
    rate,
    vx,
    tvx,
    v,
    Ax,
    Axn,
    äx,
    äxn,
    Dx,
    Mx,
    Nx,
    Cx



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
    as commutation functions or life insurance/annuity rates.

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
    Dx(lc::LifeContingency, duration)

The ``D_x`` actuarial commutation function where the `duration` argument is `x`.
"""
function Dx(lc::LifeContingency, duration)
    tvx(lc.int, duration, 1) * p(lc.mort, lc.issue_age, 1, duration)
end

"""
    lx(lc::LifeContingency, duration)

The ``l_x`` actuarial commutation function where the `duration` argument is `x`.
"""
function lx(lc::LifeContingency, duration)
    if duration == 0
        return 1.0
    else
        return p(lc.mort, lc.issue_age, 1, duration)
    end
end

"""
    Cx(lc::LifeContingency, duration)

The ``C_x`` actuarial commutation function where the `duration` argument is `x`.
"""
function Cx(lc::LifeContingency, duration)
    tvx(lc.int, duration + 1, 1) *
    q(lc.mort, lc.issue_age, duration + 1) *
    lx(lc, duration)
end

"""
    Nx(lc::LifeContingency, duration)

The ``N_x`` actuarial commutation function where the `duration` argument is `x`.
"""
function Nx(lc::LifeContingency, x)
    range = x:(ω(lc) - lc.issue_age)
    return reduce(+, Map(x -> Dx(lc, x)), range)

end

"""
    Mx(lc::LifeContingency, duration)

The ``M_x`` actuarial commutation function where the `duration` argument is `x`.
"""
function Mx(lc::LifeContingency, x)
    range = x:(ω(lc) - lc.issue_age)
    return reduce(+, Map(x -> Cx(lc, x)), range)
end

tEx(lc::LifeContingency, t, x) = Dx(x + t) / Dx(x)


##################
### Insurances ###
##################

"""
    Axn(lc::LifeContingency, x, n)

Term insurance on age x for n years for someone starting in the `x`th duration.
"""
Axn(lc::LifeContingency, x, n) = (Mx(lc, x) - Mx(lc, x + n)) / Dx(lc, x)

"""
Ax(lc::LifeContingency, x)
Whole life insurance for someone starting in the `x`th duration.
"""
Ax(lc::LifeContingency, x) = Mx(lc, x) / Dx(lc, x)

"""
    äx(lc::LifeContingency, x)

Life annuity due for someone starting in the `x`th duration.

To enter the `ä` character, type `a` and then `\\ddot`.
    See more on how to [input unicode](https://docs.julialang.org/en/v1/manual/unicode-input/index.html)
    in Julia.

"""
äx(lc::LifeContingency, x) = Nx(lc, x) / Dx(lc, x)

"""
    äx(lc::LifeContingency, x,n)

Life annuity due for someone starting in the `x`th duration for `n` years.

To enter the `ä` character, type `a` and then `\\ddot`.
    See more on how to [input unicode](https://docs.julialang.org/en/v1/manual/unicode-input/index.html)
    in Julia.

"""
äxn(lc::LifeContingency, x, n) = (Nx(lc, x) - Nx(lc, x + n)) / Dx(lc, x)

end # module
