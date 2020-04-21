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
include("decrement.jl")
# include("mortality.jl")




# 'actuarial objects' that combine multiple forms of decrements (lapse, interest, death, etc)
abstract type AbstractActuarial end

mutable struct LifeContingency
    mort
    int::InterestRate
    issue_age::Int
end

function ω(lc::LifeContingency, x; fromlast = 0)
    # if one of the omegas is infinity, that's a Float so we need
    # to narrow the type with Int
    return Int(min(mt.ω(lc.mort, lc.issue_age), ω(lc.int)) - fromlast)
end

###################
## COMMUTATIONS ###
###################

function Dx(lc::LifeContingency, duration)
    tvx(lc.int, duration, 1) * p(lc.mort, lc.issue_age, 1, duration)
end

function lx(lc::LifeContingency, duration)
    if duration == 0
        return 1.0
    else
        return p(lc.mort, lc.issue_age, 1, duration)
    end
end

function Cx(lc::LifeContingency, duration)
    tvx(lc.int, duration + 1, 1) *
    q(lc.mort, lc.issue_age, duration + 1) *
    lx(lc, duration)
end

function Nx(lc::LifeContingency, x)
    range = x:ω(lc, x; fromlast = 0)
    return reduce(+, Map(x -> Dx(lc, x)), range)

end

function Mx(lc::LifeContingency, x)
    range = x:ω(lc, x; fromlast = 1)
    return reduce(+, Map(x -> Cx(lc, x)), range)
end

tEx(lc::LifeContingency, t, x) = Dx(x + t) / Dx(x)


##################
### Insurances ###
##################

#term insurance on age x for n years
Axn(lc::LifeContingency, x, n) = (Mx(lc, x) - Mx(lc, x + n)) / Dx(lc, x)

# whole life insurance
Ax(lc::LifeContingency, x) = Mx(lc, x) / Dx(lc, x)

# life annuity due
äx(lc::LifeContingency, x) = Nx(lc, x) / Dx(lc, x)

# finite duration life annuity due
äxn(lc::LifeContingency, x, n) = (Nx(lc, x) - Nx(lc, x + n)) / Dx(lc, x)

end # module
