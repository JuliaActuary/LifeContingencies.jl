module ActuarialScience
using MortalityTables
using Transducers

const mt = MortalityTables

export maleMort, femaleMort,
        LifeContingency,
        qx,px, tpx, tqx,
        tqxy,tpxy, tqx̅y̅, tpx̅y̅,
        lx, dx, ex,
        ixVector,
        InterestRate,
        rate,vx,tvx,v,
        Ax, Axn, äx,äxn,
        Dx, Mx, Nx, Cx

# Social Security Mortality
maleMort = [0.00699,0.000447,0.000301,0.000233,0.000177,0.000161,0.00015,0.000139,0.000123,0.000105,0.000091,0.000096,0.000135,0.000217,0.000332,0.000456,0.000579,0.000709,0.000843,0.000977,0.001118,0.00125,0.001342,0.001382,0.001382,0.00137,0.001364,0.001362,0.001373,0.001393,0.001419,0.001445,0.001478,0.001519,0.001569,0.001631,0.001709,0.001807,0.001927,0.00207,0.002234,0.00242,0.002628,0.00286,0.003117,0.003396,0.003703,0.004051,0.004444,0.004878,0.005347,0.005838,0.006337,0.006837,0.007347,0.007905,0.008508,0.009116,0.009723,0.010354,0.011046,0.011835,0.012728,0.013743,0.014885,0.016182,0.017612,0.019138,0.020752,0.022497,0.024488,0.026747,0.029212,0.031885,0.034832,0.038217,0.042059,0.046261,0.050826,0.055865,0.06162,0.068153,0.075349,0.08323,0.091933,0.101625,0.112448,0.124502,0.137837,0.152458,0.168352,0.185486,0.203817,0.223298,0.243867,0.264277,0.284168,0.303164,0.320876,0.336919,0.353765,0.371454,0.390026,0.409528,0.430004,0.451504,0.474079,0.497783,0.522673,0.548806,0.576246,0.605059,0.635312,0.667077,0.700431,0.735453,0.772225,0.810837,0.851378,0.893947]

femaleMort = [0.005728,0.000373,0.000241,0.000186,0.00015,0.000133,0.000121,0.000112,0.000104,0.000098,0.000094,0.000098,0.000114,0.000143,0.000183,0.000229,0.000274,0.000314,0.000347,0.000374,0.000402,0.000431,0.000458,0.000482,0.000504,0.000527,0.000551,0.000575,0.000602,0.00063,0.000662,0.000699,0.000739,0.00078,0.000827,0.000879,0.000943,0.00102,0.001114,0.001224,0.001345,0.001477,0.001624,0.001789,0.001968,0.002161,0.002364,0.002578,0.0028,0.003032,0.003289,0.003559,0.003819,0.004059,0.004296,0.004556,0.004862,0.005222,0.005646,0.006136,0.006696,0.007315,0.007976,0.008676,0.009435,0.010298,0.011281,0.01237,0.013572,0.014908,0.01644,0.018162,0.020019,0.022003,0.024173,0.026706,0.029603,0.032718,0.036034,0.039683,0.043899,0.048807,0.054374,0.060661,0.067751,0.075729,0.084673,0.094645,0.105694,0.117853,0.131146,0.145585,0.161175,0.17791,0.195774,0.213849,0.231865,0.249525,0.266514,0.282504,0.299455,0.317422,0.336467,0.356655,0.378055,0.400738,0.424782,0.450269,0.477285,0.505922,0.536278,0.568454,0.602561,0.638715,0.677038,0.71766,0.76072,0.806363,0.851378,0.893947]


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

function ω(lc::LifeContingency,x;fromlast=0)
        # if one of the omegas is infinity, that's a Float so we need
        # to narrow the type with Int
        return Int(min(mt.ω(lc.mort,lc.issue_age),ω(lc.int))-fromlast)
end

###################
## COMMUTATIONS ###
###################

function Dx(lc::LifeContingency,duration)
        tvx(lc.int,duration,1) * p(lc.mort,lc.issue_age,1,duration)
end

function lx(lc::LifeContingency,duration)
        if duration == 0
            return 1.0
        else
            return p(lc.mort,lc.issue_age,1,duration)
        end
end

function Cx(lc::LifeContingency,duration)
        tvx(lc.int,duration+1,1) * q(lc.mort,lc.issue_age,duration+1) * lx(lc,duration)
end

function Nx(lc::LifeContingency,x)
        range =x:ω(lc,x;fromlast=0)
    return reduce(+, Map(x -> Dx(lc,x)), range)

end

function Mx(lc::LifeContingency,x)
    range =  x:ω(lc,x;fromlast=1)
    return reduce(+, Map(x -> Cx(lc,x)), range)
end

tEx(lc::LifeContingency,t,x) = Dx(x+t) / Dx(x)


##################
### Insurances ###
##################

#term insurance on age x for n years
Axn(lc::LifeContingency,x,n) = (Mx(lc,x) - Mx(lc,x + n) ) / Dx(lc,x)

# whole life insurance
Ax(lc::LifeContingency,x) = Mx(lc,x) / Dx(lc,x)

# life annuity due
äx(lc::LifeContingency,x) = Nx(lc,x) / Dx(lc,x)

# finite duration life annuity due
äxn(lc::LifeContingency,x,n) = (Nx(lc,x) - Nx(lc,x+n) )/ Dx(lc,x)

end # module
