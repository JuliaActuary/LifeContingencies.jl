include("decrement.jl")

"""
    InterestRate() 

`InterestRate` is an abstract type that is the parent of various 
concrete implementations of interest rate calculations.
"""
abstract type InterestRate <: Decrement end

"""
    FunctionalInterestRate()

`FunctionalInterestRate` is a struct with a `rate_function` that is a function that
takes a time and returns an annual interst rate for that time. Construct by calling
    `InterestRate()` with a function as an argument. 

# Examples
    # simply return 5% always
    InterestRate(time -> 0.05) 
    
    # for every period, return a normally distrubted rate
    InterestRate((x -> rand(Normal(0.05, 0.01))))

    # an autocorrelated rate
    InterestRate(
            time -> time <= 1 ? 0.05 : rand(Normal(last(i5.rate_vector), 0.01)),
        )
"""
struct FunctionalInterestRate{F} <: InterestRate
    rate_vector::Array{Float64,1}
    rate_function::F
end

"""
    VectorInterestRate()

`VectorInterestRate` is a struct with a given vector where the element `t` is the rate at time `t`.
Construct by calling `InterestRate()` with a vector as an argument. Note that if you provide a short
vector, you may inhibit other methods (e.g. commutation/insurance calculations) becuase you haven't 
defined interest rates for longer-dated periods.

# Examples
    # 5% interest for years 1, 2, and 3
    InterestRate([0.05, 0.05, 0.05])
"""
struct VectorInterestRate{T} <: InterestRate
    rate_vector::Array{T,1}
end


"""
    ConstantInterestRate()

`ConstantInterestRate` is a struct with a given rate that will act as the same rate for all periods.
Construct by calling `InterestRate()` with a rate as an argument. 

# Examples
    # 5% interest for all years
    InterestRate()
"""
struct ConstantInterestRate <: InterestRate
    rate
end


"""
    InterestRate(v::Vector{Float64})

Construct a `VectorInterestRate`.
"""
function InterestRate(v::Vector{Float64})
    VectorInterestRate(v)
end

"""
    InterestRate(i::Real)

Construct a `ConstantInterestRate`.
"""
function InterestRate(i::Real)
    ConstantInterestRate(i)
end

"""
    InterestRate(f)

Construct a `FunctionalInterestRate`. Assumes that `f` is a function that takes a given time
period and returns the annual effective rate for that period.
"""
function InterestRate(f)
    FunctionalInterestRate(Vector{Float64}(undef, 0), f)
end

"""
        rate(i::InterestRate,time)

The interst during time `time.`
"""
function rate(i::ConstantInterestRate, time)
    return i.rate
end

function rate(i::FunctionalInterestRate{F}, time) where {F}
    if time <= lastindex(i.rate_vector)
        return i.rate_vector[time]
    else
        rate = i.rate_function(time)
        push!(i.rate_vector, rate)
        return rate
    end
end

function rate(i::VectorInterestRate, time)
    return i.rate_vector[time]
end

"""
    v(iv::InterestRate, time1, time2, init = 1.0)
The discount rate from `time1` to `time2` with the initial (time zero)
discount factor of `1.0`. Currently only supports whole years.
"""
function v(iv::InterestRate, time1, time2, init = 1.0)
    if time1 > 0
        return v(iv, time1 - 1, time2 + 1, init / (1 + rate(iv, time2)))
    else
        return init
    end
end

""" 
    ω(i::InterestRate)

The last period that the interest rate is defined for. Assumed to be infinite (`Inf`) for 
    functional and constant interest rate types. Returns the `lastindex` of the vector if 
    a vector type. Also callable using `omega` instead of `ω`.

"""
function mt.ω(i::ConstantInterestRate)
    return Inf
end

function mt.ω(i::VectorInterestRate)
    return lastindex(i.i)
end

function mt.ω(i::FunctionalInterestRate{F}) where {F}
    return Inf
end


### Convienence functions

"""
    v(i::InterestRate, time)    
The discount rate at time `time`.
"""
v(i::InterestRate, time) = v(i, 1, time, 1.0)

"""
    v(i::InterestRate)
The discount rate at time `1`.
"""
v(i::InterestRate) =  v(i, 1)
