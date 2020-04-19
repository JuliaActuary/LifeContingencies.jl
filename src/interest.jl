include("decrement.jl")

const ixVector = Vector{Float64}

mutable struct InterestRate{F} <: Decrement
    ix::Array{Float64,1}
    ifx::F
end

# constructor with a predefined vector
function InterestRate(v::ixVector)
    new(v,(x -> v[x]))
end

# constructor with a real number argument converts to a function that will produce an interest rate
function InterestRate(i::Real)
    new(Vector{Float64}(undef, 0),(x -> i))
end

# constructor with (any) argument assumes a function that will produce an interest rate
function InterestRate(f)
    new(Vector{Float64}(undef, 0),f)
end
# constructor with (any) argument assumes a function that will produce an interest rate
# and provided rates for the first n... time periods
function InterestRate(f, x...)
    new(collect(x),f)
end


# the interst during time x
function i(iv::InterestRate,x)
    if x < 0 # looking for nth item from end of vector
        return iv.ix[end + Int(x) + 1]
    elseif length(iv.ix) < x
        append!(iv.ix, iv.ifx(length(iv.ix)+1))
        return i(iv,x)
    else   
        return iv.ix[Int(x)]
    end
end

# the discount rate from time x to x+t
function tvx(iv::InterestRate,t,x, v=1.0)
    if t > 0
        return tvx(iv,t-1,x+1,v / (1.0 + i(iv,x)))
    else
        return v
    end
end

# ω (omega), the ultimate end of the given table 
function ω(i::InterestRate)
    if length(i.ix) == 0
        return Inf
    else    
        return length(i.ix)
    end
end
w(iv::InterestRate) = ω(iv)

### Convienence functions

# the discount rate at time x
vx(iv::InterestRate,x) = tvx(iv,1.0,x,1.0)

# the discount rate at time 1
v(iv::InterestRate) = vx(iv,1.0)


