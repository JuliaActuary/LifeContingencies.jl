abstract type InterestCompounding end

struct Simple <: InterestCompounding end
struct Compound <: InterestCompounding end
struct Continuous <: InterestCompounding end

"""
    InterestRate(vector)
    InterestRate(constant_rate) 

`InterestRate` is an abstract type that is the parent of various  concrete implementations of interest rate calculations.

Note that if you provide a short vector, you may inhibit other methods (e.g. commutation/insurance calculations) becuase you haven't defined interest rates for longer-dated periods.

# Examples

```julia

julia> i = InterestRate([0.05, 0.05, 0.05])
julia> i = InterestRate(0.05)

```

"""
abstract type InterestRate end

struct VectorInterestRate <: InterestRate
    rate
    compound::InterestCompounding
end

struct ConstantInterestRate <: InterestRate
    rate
    compound::InterestCompounding
end

function InterestRate(v::Vector{Float64}; compound=Compound())
    VectorInterestRate(v,compound)
end

function InterestRate(i::Real; compound=Compound())
    ConstantInterestRate(i,compound)
end


# make interest rates broadcastable
Base.broadcastable(i::InterestRate) = Ref(i)


"""
        rate(i::InterestRate,time)

The interst during time `time.`
"""
function rate(i::ConstantInterestRate, time)
    return i.rate
end

function rate(i::VectorInterestRate, time)
    return i.rate[time]
end

"""
    disc(i::InterestRate, from_period, to_period)
    disc(i::InterestRate, period)
    disc(lc::LifeContingency, period)

The three argument method returns the discount factor applicable between period `from_period` and `to_period` given `InterestRate` `i`.
The two argument method returns the discount factor from period zero to `period` given `InterestRate` `i`.

# Examples
```julia-repl
julia> i = InterestRate(0.05)
julia> disc(i,1)
0.9523809523809523
julia> v.(i,1:5)
5-element Array{Float64,1}:
 0.9523809523809523
 0.9070294784580498
 0.863837598531476
 0.8227024747918819
 0.7835261664684589
 julia> disc(i,1,3)
0.9070294784580498
```

"""

"""
    disc(i::InterestRate, to_time)    
The discount rate at time `to_time`.
"""
function disc(i::InterestRate, to_time)
    if to_time == 0
        1.0
    else
        disc(i,0,to_time)
    end
end

function disc(i::InterestRate, from_time, to_time) 
    return disc(i.compound,i,from_time,to_time)
end

function disc(::Compound,i::ConstantInterestRate, from_time, to_time) 
    1.0 / (1 + i.rate) ^ (to_time - from_time)
end
function disc(::Simple,i::ConstantInterestRate, from_time, to_time) 
    1.0 / (1 + i.rate * (to_time - from_time))
end
function disc(::Continuous,i::ConstantInterestRate, from_time, to_time) 
    1.0 / exp(rate(i) * (to_time - from_time))
end

function disc(i::VectorInterestRate, from_time, to_time) 
    return disc(i.compound,i,from_time,to_time)
end

function disc(::Compound,i::VectorInterestRate, from_time, to_time) 
    #won't handle non-int times
    reduce(/, 1 .+ rate.(i,(from_time+1):to_time);init=1.0 )
end

# Iterators

"""
    DiscountFactor(int::InterestRate,time_step)

An iterator version of an interest rate which will generate a discount vector that is as long as need. This is useful because in the a lot of actuarial calculations, you have a variable ending point (`omega`) in a lot of calculations, but you just want the interest to expand as necessary to fit your vector.

`timestep` is the fractional portion of the rate period. E.g. if you are using annual rates, then `time_step` is fraction of the year in each of the itereated time steps.

Can also be constructed by passing a `timestep` to an `InterestRate`. See example below.

# Examples
```julia-repl
julia> time_step = 1;
julia> disc_factor = InterestRate(0.05)(time_step)

julia> using IterTools
julia> Iterators.take(df,5) |> collect
5-element Array{Any,1}:
 1.0
 0.9523809523809523
 0.9070294784580498
 0.863837598531476
 0.8227024747918819
```
"""
struct DiscountFactor{T<:InterestRate}
    int::T
    time_step 
end

(i::InterestRate)(time_period) = DiscountFactor(i,time_period)

function Base.iterate(df::DiscountFactor{T}) where {T<:InterestRate}
    return (1.0,(v = 1.0 * disc(df.int,df.time_step),time = df.time_step))
end

function Base.iterate(df::DiscountFactor{T},state) where {T<:InterestRate}
    new_time =  state.time + df.time_step
    return (state.v,(v = state.v  * disc(df.int,state.time,new_time),time = new_time))
end

function Base.iterate(df::DiscountFactor{VectorInterestRate},state)
    
    isnothing(state) && return nothing

    if state.time + 1 >= length(df)
        next = nothing
    else
        new_time =  state.time + df.time_step
        next = (v = state.v  * disc(df.int,state.time,new_time), time  = new_time)
    end
    return (
        state.v,
        next
        )
end
function Base.IteratorSize(::Type{<:DiscountFactor{T}}) where {T<:InterestRate}
    # if SizeUnkown, then can end up growing infinitely with `collect` for FunctionalInterestRate
    return Base.IsInfinite()
end

function Base.length(df::DiscountFactor{VectorInterestRate})
    return length(df.int.rate) + 1
end

function Base.IteratorSize(::Type{<:DiscountFactor{VectorInterestRate}})
    return Base.HasLength()
end

DiscountFactor{LifeContingencies.VectorInterestRate}(LifeContingencies.VectorInterestRate([0.05, 0.05, 0.05, 0.05], LifeContingencies.Compound()), 1) 
DiscountFactor{LifeContingencies.VectorInterestRate}(LifeContingencies.VectorInterestRate([0.05, 0.05, 0.05, 0.05], LifeContingencies.Compound()), 1)