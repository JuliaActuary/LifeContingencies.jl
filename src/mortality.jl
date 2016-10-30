include("decrement.jl")

typealias qxVector Vector{Float64}


testMort = [0.00699,0.000447,0.000301,0.000233,0.000177,0.000161,0.00015,0.000139,0.000123,0.000105,0.000091,0.000096,0.000135,0.000217,0.000332,0.000456,0.000579,0.000709,0.000843,0.000977,0.001118,0.00125,0.001342,0.001382,0.001382,0.00137,0.001364,0.001362,0.001373,0.001393,0.001419,0.001445,0.001478,0.001519,0.001569,0.001631,0.001709,0.001807,0.001927,0.00207,0.002234,0.00242,0.002628,0.00286,0.003117,0.003396,0.003703,0.004051,0.004444,0.004878,0.005347,0.005838,0.006337,0.006837,0.007347,0.007905,0.008508,0.009116,0.009723,0.010354,0.011046,0.011835,0.012728,0.013743,0.014885,0.016182,0.017612,0.019138,0.020752,0.022497,0.024488,0.026747,0.029212,0.031885,0.034832,0.038217,0.042059,0.046261,0.050826,0.055865,0.06162,0.068153,0.075349,0.08323,0.091933,0.101625,0.112448,0.124502,0.137837,0.152458,0.168352,0.185486,0.203817,0.223298,0.243867,0.264277,0.284168,0.303164,0.320876,0.336919,0.353765,0.371454,0.390026,0.409528,0.430004,0.451504,0.474079,0.497783,0.522673,0.548806,0.576246,0.605059,0.635312,0.667077,0.700431,0.735453,0.772225,0.810837,0.851378,0.893947]

testMort = convert(qxVector,testMort)

type MortalityTable <: Decrement
    qx::Vector{Float64}
    lx::Vector{Float64}

    function MortalityTable(v::qxVector)
        lx = [1000.0]
        for (i,q) in enumerate(v) 
            append!(lx,lx[end]*(1-q))
        end 
        new(v,lx)
    end

end

#############
## BASICS ###
#############

# the probability that life age x dies in within the next year
function qx(mt::MortalityTable,x)
    if x < length(mt.qx)
        return mt.qx[x+1]
        else
        return 0
    end
end 

# the number of lives remaining at age x (starting at 100)
function lx(mt::MortalityTable,x)
    x = Int(x)
    if x < length(mt.lx)
        return mt.lx[x+1]
        else
        return 0
    end
end 

# ω (omega), the ultimate age of the given table 
ω(mt::MortalityTable) = length(mt.qx)
w(mt::MortalityTable) = ω(mt) #convienence



# the number dying within the year (basis is 1000)
function dx(mt::MortalityTable,x)
    x = Int(x)
    if x >= length(mt.lx)
        return 0.0
    else
        return lx(mt,x) - lx(mt,x+1)
    end
end

# the probability of surviving one year from age x
function px(mt::MortalityTable,x)
    return 1 - px(mt,x)
end

# the probability of surviving for t  years from age x
function tpx(mt::MortalityTable,x, t)
    return lx(mt,x + t) / lx(mt,x)
end

# the probability of dying within t years from age x
function tqx(mt::MortalityTable,x,t)
    return 1 - tpx(mt,x,t)
end

# the curtate life expectancy from age x
function ex(mt::MortalityTable,x)
    try return sum(mt.lx[x+1:end])/mt.lx[x+1] + 0.5
    catch return 0.0
    end
end