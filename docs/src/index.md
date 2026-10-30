# LifeContingencies.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://docs.juliaactuary.org/LifeContingencies/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://docs.juliaactuary.org/LifeContingencies/dev/)
![](https://github.com/JuliaActuary/LifeContingencies.jl/workflows/CI/badge.svg)
[![codecov](https://codecov.io/gh/JuliaActuary/LifeContingencies.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaActuary/LifeContingencies.jl)

LifeContingencies is a package for actuarial life-contingent calculations: survival, life
insurance and annuity values, net premiums and reserves, for single and joint lives.

## Features

- Mortality from [MortalityTables.jl](https://github.com/JuliaActuary/MortalityTables.jl):
  rate vectors, select and ultimate tables, and parametric laws such as Gompertz.
- Interest as a single rate, or any yield curve that
  [FinanceCore.jl](https://github.com/JuliaActuary/FinanceCore.jl) can discount with, such as
  those from [FinanceModels.jl](https://github.com/JuliaActuary/FinanceModels.jl).
- Single lives, and joint lives (`LastSurvivor` and `FirstToDie`), each with a status at issue.
- Products:
  - life insurance
  - annuities due and immediate, with terms, deferral, guaranteed periods and payment
    frequency
- Valuation:
  - net premiums
  - net premium reserves, from a known state if you like
- Actuarial notation shorthand (`A`, `ä`, `V`, …) and commutation functions.
- An experimental [multi-state engine](ltc.md) for products such as long-term care.

## Getting started

Values for a 30-year-old male nonsmoker on the 2001 VBT select and ultimate table, at a flat
5% rate:

```@example basics
using LifeContingencies, MortalityTables

vbt2001 = MortalityTables.table("2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB")
life = SingleLife(vbt2001.select[30])   # select rates for issue age 30
lc = LifeContingency(life, 0.05)        # a flat 5% rate; a FinanceModels yield curve also works
ins = Insurance(lc)                     # whole life insurance
present_value(ins)
```

Each insurance can also be inspected year by year. Here are the first three policy years'
timepoints, benefit probabilities, cash flows, survival and discount factors:

```@example basics
timepoints(ins)[1:3], probability(ins)[1:3], cashflows(ins)[1:3], survival(ins)[1:3], discount(ins)[1:3]
```

The net annual premium for whole life, and the net premium reserve at the end of year 5:

```@example basics
premium_net(lc), reserve_premium_net(lc, 5)
```

Other products:

```@example basics
[
    "10-year term insurance" => present_value(Insurance(lc, 10)),
    "life annuity due" => present_value(AnnuityDue(lc)),
    "life annuity immediate" => present_value(AnnuityImmediate(lc)),
    "10-year annuity due, quarterly, 5 years certain" => present_value(AnnuityDue(lc, 10; certain=5, frequency=4)),
    "life annuity due deferred 35 years" => present_value(AnnuityDue(lc; start_time=35)),
]
```

`present_value(ins, t)` values the payments after time `t` as of time `t`.

## Constructing lives

```@example basics
SingleLife(vbt2001.select[50]).issue_age,             # the issue age comes from the select row
SingleLife(vbt2001.select, issue_age=50).issue_age,   # the same, picking the row by issue age
SingleLife(vbt2001.ultimate, issue_age=60).issue_age  # ultimate rates from age 60
```

A life can also use a parametric mortality law, or start out dead, which is useful in joint
lives with known statuses:

```@example basics
gompertz = SingleLife(MortalityTables.Gompertz(a=0.0002, b=0.13), issue_age=40)
dead = SingleLife(vbt2001.select[30]; alive=false)
survival(gompertz, 30), survival(dead, 1)
```

## When the mortality assumption runs out

A whole-life contract needs mortality rates that reach extinction, a rate of 1. The 2001 VBT
does. The 2015 VBT relative-risk tables stop at age 120 with a rate of 0.5, so a whole-life
insurance on them is undefined:

```@example basics
vbt2015 = MortalityTables.table("2015 VBT Male Non-Smoker RR100 ANB")
life2015 = SingleLife(vbt2015.ultimate, issue_age=60)
try
    present_value(Insurance(life2015, 0.05))
catch err
    err
end
```

Insurance to the end of the table makes the truncation explicit:

```@example basics
present_value(Insurance(life2015, 0.05, omega(life2015)))
```

Parametric mortality never reaches extinction, so lifetime products on it need a term too.

## Stochastic interest rates

Each scenario can carry its own rate. Here is the average net premium for 10-year term
insurance over normally distributed level rates:

```@example basics
import Random
Random.seed!(2026)
scenarios = 0.05 .+ 0.01 .* randn(1_000)
premiums = [premium_net(LifeContingency(life, rate), 10) for rate in scenarios]
sum(premiums) / length(premiums)
```

A yield curve from FinanceModels.jl can stand in for the rate to model a term structure.

## Premiums across mortality tables

The net annual premium for whole life insurance by issue age, on two tables:

```@example basics
tables = [
    MortalityTables.table("1980 CET - Male Nonsmoker, ANB"),
    MortalityTables.table("2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB"),
]
issue_ages = 30:10:80
[t.metadata.name => [round(premium_net(LifeContingency(SingleLife(t.ultimate, issue_age=age), 0.05)), digits=5) for age in issue_ages] for t in tables]
```

## Joint lives

```@example basics
cia_male = MortalityTables.table("1986-92 CIA – Male Smoker, ANB")
cia_female = MortalityTables.table("1986-92 CIA – Female Nonsmoker, ANB")
lives = (SingleLife(cia_male.ultimate, issue_age=40), SingleLife(cia_female.ultimate, issue_age=37))
last_survivor = LifeContingency(JointLife(lives=lives), 0.05)
first_to_die = LifeContingency(JointLife(lives=lives, contingency=FirstToDie()), 0.05)
present_value(Insurance(last_survivor)), present_value(AnnuityDue(first_to_die))
```

A reserve conditions on the contract being in force. Pass `state` to value it from a known
state instead:

```@example basics
reserve_premium_net(last_survivor, 10),                          # in force: either or both alive
reserve_premium_net(last_survivor, 10; state=(:alive, :alive)),  # both alive
reserve_premium_net(last_survivor, 10; state=(:dead, :alive))    # only the second life alive
```

## Commutation and unexported function shorthand

Because it's so common to use certain variables in your own code, LifeContingencies avoids exporting certain variables/functions so that it doesn't collide with your own usage. For example, you may find yourself doing something like:

```julia
a = ...
b = ...
result = b - a
```

If you imported `using LifeContingencies` and the package exported `a` (an annuity immediate's present value), the above could break. So the package exports only the long forms, such as `present_value(AnnuityImmediate(...))`. To use the shorthand, bring it into your code's scope like so:

```julia
using LifeContingencies # brings all the default functions into your scope
using LifeContingencies: a, ä # also brings the short-form annuity functions into scope
```

**Or** you can do the following:

```julia
using LifeContingencies # brings all the default functions into your scope
... # later on in the code
LifeContingencies.ä(...) # utilize the unexported function with the module name
```

For more on module scoping, see the [Julia Manual section](https://docs.julialang.org/en/latest/manual/modules/#Summary-of-module-usage-1).

### Actuarial notation shorthand

```julia
V => reserve_premium_net
v => discount
A => present value of Insurance
ä => present value of AnnuityDue
a => present value of AnnuityImmediate
P => premium_net
ω => omega
```

### Commutation functions

```julia
l,
D,
M,
N,
C,
```

## References

- Life Insurance Mathematics, Gerber
- [Actuarial Mathematics and Life-Table Statistics, Slud](http://www2.math.umd.edu/~slud/s470/BookChaps/Chp6.pdf)
- [Commutation Functions, MacDonald](http://www.macs.hw.ac.uk/~angus/papers/eas_offprints/commfunc.pdf)
