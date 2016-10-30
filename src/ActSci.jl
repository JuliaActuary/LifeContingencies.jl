module ActSci

export testMort, 
        MortalityTable,
        qx,px, tpx, tqx,
        ω,w, lx, dx, ex,
        ixVector,
        InterestRate,
        i,vx,tvx,v,
        LifeInsurance,
        Ax, Axn, äx,äxn,
        Dx, Mx

include("interest.jl")
include("decrement.jl")
include("mortality.jl")



# 'actuarial objects' that combine multiple forms of decrements (lapse, interest, death, etc)
abstract AbstractActuarial

type ActuarialHelper
    mort::MortalityTable
    int::InterestRate
end

type LifeInsurance <: AbstractActuarial
    ah::ActuarialHelper

    function LifeInsurance(mt::MortalityTable,int::InterestRate)
        return new(ActuarialHelper(mt,int))
    end
end

###################
## COMMUTATIONS ###
###################

Dx(ah::ActuarialHelper,x) = tvx(ah.int,x,0) * lx(ah.mort,x)

preMx(ah::ActuarialHelper,x) = tvx(ah.int,x+1,0) * dx(ah.mort,x)

function Nx(ah::ActuarialHelper,x)
range =x:min(ω(ah.mort),ω(ah.int))
    return sum(map((y) -> Dx(ah,y),range))
end

function Mx(ah::ActuarialHelper,x)
    range =  x:(min(ω(ah.mort),ω(ah.int))-1)
    return sum(map((x -> preMx(ah,x)),range))
end
tEx(ah::ActuarialHelper,t,x) = Dx(x+t) / Dx(x)


##################
### Insurances ###
##################

#term insurance on age x for n years
Axn(ins::LifeInsurance,x,n) = (Mx(ins.ah,x) - Mx(ins.ah,x + n) ) / Dx(ins.ah,x)

# whole life insurance
Ax(ins::LifeInsurance,x) = Mx(ins.ah,x) / Dx(ins.ah,x)

# life annuity due 
äx(ins::LifeInsurance,x) = Nx(ins.ah,x) / Dx(ins.ah,x)

# finite duration life annuity due 
äxn(ins::LifeInsurance,x,n) = (Nx(ins.ah,x) - Nx(ins.ah,x+n) )/ Dx(ins.ah,x)

Dx(ins::LifeInsurance,x) = Dx(ins.ah,x)
Mx(ins::LifeInsurance,x) = Mx(ins.ah,x)

end # module