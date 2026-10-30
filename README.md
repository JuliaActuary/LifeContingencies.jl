# LifeContingencies.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://docs.juliaactuary.org/LifeContingencies/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://docs.juliaactuary.org/LifeContingencies/dev/)
[![CI](https://github.com/JuliaActuary/LifeContingencies.jl/workflows/CI/badge.svg)](https://github.com/JuliaActuary/LifeContingencies.jl/actions)
[![codecov](https://codecov.io/gh/JuliaActuary/LifeContingencies.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaActuary/LifeContingencies.jl)

LifeContingencies calculates survival, life insurance and annuity values, net premiums and
net premium reserves for single and joint lives. An experimental finite-state engine also
supports custom multi-state models, including recovery and duration-dependent benefits.

## Install and try it

Requires **Julia 1.10+** and **MortalityTables 3**. In Julia's package mode:

```text
pkg> add LifeContingencies MortalityTables
```

```julia
using LifeContingencies, MortalityTables

rates = UltimateMortality([0.5, 0.5, 1.0]; start_age=60)
life = SingleLife(rates)
lc = LifeContingency(life, 0.05)

present_value(Insurance(lc))        # unit benefit at the end of the year of death
present_value(Insurance(lc, 2))     # two-year term insurance
present_value(AnnuityDue(lc))       # unit annual payments in advance while alive
premium_net(lc)                     # net annual premium, fixed at issue
reserve_premium_net(lc, 1)          # in force at year one, before its premium
```

## Learn more

- [Getting started](https://docs.juliaactuary.org/LifeContingencies/stable/getting-started/)
- [Insurance, annuities and guarantees](https://docs.juliaactuary.org/LifeContingencies/stable/insurance-and-annuities/)
- [Valuation and reserves](https://docs.juliaactuary.org/LifeContingencies/stable/valuation-and-reserves/)
- [Building multi-state models](https://docs.juliaactuary.org/LifeContingencies/stable/multi-state-models/)
- [LTC worked example](https://docs.juliaactuary.org/LifeContingencies/stable/ltc/)
- [Migrating from 2.x](https://docs.juliaactuary.org/LifeContingencies/stable/migration/) and [NEWS](NEWS.md)

The [development docs](https://docs.juliaactuary.org/LifeContingencies/dev/) describe unreleased
changes. The textbook API is stable; interfaces in `LifeContingencies.Experimental` may
change in minor releases.
