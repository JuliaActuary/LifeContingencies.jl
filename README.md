# ActuarialScience -  v0.1.1
## A new actuarial modeling library

#### Code Review: [![Build Status](https://travis-ci.org/alecloudenback/ActuarialScience.jl.svg?branch=master)](https://travis-ci.org/alecloudenback/ActuarialScience.jl) [![Coverage Status](https://coveralls.io/repos/github/alecloudenback/ActuarialScience.jl/badge.svg?branch=master)](https://coveralls.io/github/alecloudenback/ActuarialScience.jl?branch=master) [![codecov.io](http://codecov.io/github/alecloudenback/ActuarialScience.jl/coverage.svg?branch=master)](http://codecov.io/github/alecloudenback/ActuarialScience.jl?branch=master)

A library to bring actuarial science to Julia.

## Project Goals
The goal is ultimately to build out a modeling package, capable of doing much more than simple commutations.

## New in this version
 - Refine interest rate periods:
   - Period `0` now is meaningless, period `1` now refers to the time period `(0,1]` 
 - Add ability to use serial correlation to interest rates (see interest rate section for example)
 - Add memory of functional interest rates
    - Prior calls to interest rates record the interst rate, so each call to a stochastic interest rate function don't generate an entirely new stream of interest rates, even if it's the same interest rate object 

## Usage



```julia
using ActuarialScience
using Plots
plotlyjs()
using Distributions
```
## Mortality


```julia
# ActuarialScience will have a number of mortality tables built into the package
# for now, there are two Social Security tables built in, maleMort and femaleMort
# e.g. femaleMort = femaleMort = [0.005728,0.000373,0.000241,...]

# to turn a vector into an interactable mortality table object, create a MortalityTable Object
m = MortalityTable(maleMort)
f = MortalityTable(femaleMort)

t = MortalityTable(maleMort)



## Examples ##

0.00699 ≈ qx(t,0)
0.000447 ≈ qx(t,1)
1000.0 == lx(t,0)  # the convention is that lx is based on 1000 lives
993.010 ≈ lx(t,1)
1000.0-1000*qx(t,0) ≈ lx(t,1)
992.5661245 ≈ lx(t,2)
120 == w(t)
0 == dx(t,150)
6.99 ≈ dx(t,0)
76.8982069 ≈ ex(t,0)
tpx(t,15,3) >= tpx(t,15,4)
tqx(t,16,2) >= tqx(t,15,2)
0 <= ex(t,15)
0.003664839851 ≈ tpx(t,22,80)

# also supports joint last survivor
tqxy(table, table, age_x, age_y,time), e.g.
tqxy(t,t,0,0,1) ≈ 0.0000488601000
tqx̅y̅(t,t,0,0,1) ≈ 0.0000488601000 #overbar notation is an option
```

## Interest


```julia
# ActuarialScience provides an easy way to specify interest rates:

i = InterestRate(.05) # you can pass interest rate a decimal value, a vector, or a function that returns a value 

# ActuarialScience currently lets you use a basic stochastic interest rate form

i2 = InterestRate((x -> rand(Normal(.05,.01))))  # anonymous function provides an easy way to add a stochastic interest rate

# Serial correlation is also allowed:
i3 = InterestRate((x -> rand(Normal(i(i3,-1),0.01))), .05)
# InterestRate(f,x...) where x is the first x... interest rates
# i(i3,-1) returns the prior period's interest rate

# Julia's power as a language comes in really handy here!
```

## Modeling


```julia
## the assumptions are joined with a "LifeInsurance" Object
insM = LifeInsurance(m,i2)
insF = LifeInsurance(f,i2)

## from there, you can calculate a number of actuarial commutations:

ins = LifeInsurance(t,i)
# Ax(ins,0) ≈ 0.04223728223

# Axn(ins,26,1) ≈ 0.001299047619
# Ax(ins,26) ≈ 0.1082172434
# äx(ins,26) = 18.727437887738578 # Julia lets you use unicode characters, so you can use the a-dot-dot as the actual function
# äx(ins,26) = 18.727437887738578 # many code editors make the unicode characters really easy, but helper functions provide compatibility
```


```julia
# calculating the net premium for a whole life policy for males and females
# using a random interest rate on


plot([map((x->1000000*Ax(insM,x)/äx(insM,x)),0:100),map((x->1000000*Ax(insF,x)/äx(insF,x)),0:100)],xlabel="Age",ylabel="Yearly Cost",yscale = :log10)
```
#### The annual net premium for a whole life policy, by age, with a random discount rate. 

![plot of insurance premiums](http://i.imgur.com/UbjrWci.png)

*This is different than what you'd actually pay for a policy, which is called a "gross premium".*  



## Roadmap
- Continue building out basic life and annuity functions
- Implement lapses
- Add reserves
- Docs
- More robust tests
- More built-in mortality tables
- TBD


## References
Sources for help with the commutation functions (since I have long since taken MLC)
- https://www.soa.org/files/pdf/edu-2009-fall-ea-sn-com.pdf
- www.math.umd.edu/~evs/s470/BookChaps/Chp6.pdf
- www.macs.hw.ac.uk/~angus/papers/eas_offprints/commfunc.pdf

Shout out to a similar Python project, whose Readme I one day hope to live up to and provided inspiration, including some of the function syntax.

 - https://github.com/franciscogarate/pyliferisk 

## Disclaimer
I provide no warranty or guarantees. This is an open source project and I encourage you to submit feedback or pull requests. It's my first foray into the promising language of Juilia, so I encourage feedback about the package desgin and code architecture.
