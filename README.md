# LifeContingencies.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://docs.juliaactuary.org/LifeContingencies/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://docs.juliaactuary.org/LifeContingencies/dev/)
![](https://github.com/JuliaActuary/LifeContingencies.jl/workflows/CI/badge.svg)
[![codecov](https://codecov.io/gh/JuliaActuary/LifeContingencies.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaActuary/LifeContingencies.jl)

LifeContingencies is a package for actuarial life-contingent calculations: survival, life
insurance and annuity values, net premiums and reserves, for single and joint lives. The
[documentation](https://docs.juliaactuary.org/LifeContingencies/stable/) has a full tour,
with every example run as the docs are built.

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
- An experimental multi-state engine for products such as long-term care.

## Quick start

```julia
using LifeContingencies, MortalityTables

vbt2001 = MortalityTables.table("2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB")
life = SingleLife(vbt2001.select[30])   # select rates for issue age 30
lc = LifeContingency(life, 0.05)        # a flat 5% rate; a FinanceModels yield curve also works

present_value(Insurance(lc))            # whole life insurance
present_value(Insurance(lc, 10))        # 10-year term insurance
present_value(AnnuityDue(lc))           # life annuity due
premium_net(lc)                         # net annual premium for whole life
reserve_premium_net(lc, 5)              # net premium reserve at the end of year 5
```

Upgrading from 2.x? [NEWS.md](NEWS.md) lists the changes in 3.0.

## References

- Life Insurance Mathematics, Gerber
- [Actuarial Mathematics and Life-Table Statistics, Slud](http://www2.math.umd.edu/~slud/s470/BookChaps/Chp6.pdf)
- [Commutation Functions, MacDonald](http://www.macs.hw.ac.uk/~angus/papers/eas_offprints/commfunc.pdf)
