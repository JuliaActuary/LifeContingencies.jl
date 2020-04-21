include("decrement.jl")

abstract type InterestRate <: Decrement end


struct FunctionalInterestRate{F} <: InterestRate
    rate_vector::Array{Float64,1}
    rate_function::F
end

struct VectorInterestRate{T} <: InterestRate
    rate_vector::Array{T,1}
end

struct ConstantInterestRate <: InterestRate
    rate
end


# constructor with a predefined vector
function InterestRate(v::Vector{Float64})
    VectorInterestRate(v)
end

# constructor with a real number argument converts to a function that will produce an interest rate
function InterestRate(i::Real)
    ConstantInterestRate(i)
end

# constructor with (any) argument assumes a function that will produce an interest rate
function InterestRate(f)
    FunctionalInterestRate(Vector{Float64}(undef, 0),f)
end

# the interst during time x
function i(i::ConstantInterestRate,time)
    return i.rate
end

function i(i::FunctionalInterestRate{F},time) where {F}
    if time <= lastindex(i.rate_vector)
        return i.rate_vector[time]
    else
        rate = i.rate_function(time)
        push!(i.rate_vector,rate)
        return rate
    end
end

function i(i::VectorInterestRate,time)
    return i.rate_vector[time]
end

"""
The discount rate from `time1` to `time2` with the initial (time zero)
discount factor of `1.0`. Currentlu only supports whole years.
"""
function tvx(iv::InterestRate,time1,time2, init=1.0)
    if time1 > 0
        return tvx(iv, time1 - 1, time2 + 1, init / (1 + i(iv, time2)))
    else
        return init
    end
end

# ω (omega), the ultimate end of the given table
function omega(i::ConstantInterestRate)
    return Inf
end

function omega(i::VectorInterestRate)
    return lastindex(i.i)
end

function omega(i::FunctionalInterestRate{F}) where F
    return Inf
end

ω(i::InterestRate) = omega(i)

### Convienence functions

"""

The discount rate at time `time`.
"""
vx(i::InterestRate,time) = tvx(i,1,time,1.0)

"""

The discount rate at time 1
"""
v(i::InterestRate) = vx(i,1)
