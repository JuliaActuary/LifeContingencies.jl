# LifeContingencies.jl

*Actuarial maths for Julia.*

## Introduction 

LifeContingencies is a package enabling actuarial life contingent calculations.
The benefits are:

- Integration with other JuliaActuary packages such as [MortalityTables.jl](https://github.com/JuliaActuary/MortalityTables.jl)
- Fast calculations, with some parts utilizing parallel processing power automatically
- Use functions that look more like the math you are used to (e.g. `Ax`, `ä`)
with [Unicode support](https://docs.julialang.org/en/v1/manual/unicode-input/index.html)
- All of the power, speed, convenience, tooling, and ecosystem of Julia
- Flexible and modular modeling approach

## Package Overview

- Leverages [MortalityTables.jl](https://github.com/JuliaActuary/MortalityTables.jl) for
the mortality calculations
- Contains common insurance calculations such as:
    - `A(x)`: Whole life
    - `A(x,n)`: Term life for `n` years
    - `ä(x)`: Life contingent annuity due
    - `ä(x,n)`: Life contingent annuity due for `n` years
- Contains various commutaion functions such as `D(x)`,`M(x)`,`C(x)`, etc.
- Various interest rate mechanics (e.g. stochastic, constant, etc.)
- More documentation available by clicking the DOCS bages at the top of this README


```@index
```

```@meta
DocTestSetup = quote
    using LifeContingencies
    using Dates
end
```

```@autodocs
Modules = [LifeContingencies]
```
