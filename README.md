# LifeContingencies.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaActuary.github.io/LifeContingencies.jl/stable/) 
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaActuary.github.io/ActuaryUtilities.jl/dev/)
![](https://github.com/JuliaActuary/LifeContingencies.jl/workflows/CI/badge.svg)

LifeContingencies is a package enabling actuarial life contingent calculations.
The benefits are:

- Integration with other JuliaActuary packages such as [MortalityTables](https://github.com/JuliaActuary/MortalityTables.jl)
- Fast calculations, with some parts utilizing parallel processing power automatically
- Use functions that look more like the math you are used to (e.g. `Ax`, `ä`)
with [Unicode support](https://docs.julialang.org/en/v1/manual/unicode-input/index.html)
- All of the power, speed, convenience, tooling, and ecosystem of Julia
- Flexible and modular modeling approach

## Package Overview

- Leverages [MortalityTables](https://github.com/JuliaActuary/MortalityTables.jl) for
the mortality calculations
- Contains common insurance calculations such as:
    - `Ax`: Whole life
    - `Axn`: Term life for `n` years
    - `äx`: Life contingent annuity due
    - `äxn`: Life contingent annuity due for `n` years
- Contains various commutaion functions such as `Dx`,`Mx`,`Cx`, etc.
- Various interest rate mechanics (e.g. stochastic, constant, etc.)
- More documentation available by clicking the DOCS bages at the top of this README

## Examples

Calculate the whole life insurance rate for a 30-year-old male nonsmoker using
2015 VBT base table and a 5% interest rate

```julia
using LifeContingencies, MortalityTables

tbls = MortalityTables.tables()
vbt2001 = tbls["2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB"]
issue_age = 30
l = LifeContingency(
    vbt2001.select,
    InterestRate(0.05),
    issue_age
    )

start_time = 0
Ax(l,start_time) # 0.111...
```

Use a stochastic interest rate calculation to price a term policy:

```julia
using LifeContingencies, MortalityTables
using Distributions

tbls = MortalityTables.tables()
vbt2001 = tbls["2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB"]

# use an interest rate that's normally distirbuted
μ = 0.05
σ = 0.01
int = InterestRate(t -> rand(Normal(μ,σ)))

l = LifeContingency(
    vbt2001.select,
    int,
    30 # issue age
    )

start_time = 0
term = 10
Axn(l,start_time,term) # somewhere around 0.055
```

You can use autocorrelated interest rates - substitute the following in the prior example
using the ability to self reference:

```julia
σ = 0.01
initial_rate = 0.05
int = InterestRate(
    function intAR(time)
        if time <= 1
            initial_rate
        else
            i′ = last(int.rate_vector)
            rand(Normal(i′,σ))
        end
    end
)

```

Compare the cost of annual premium, whole life insurance between multiple tables visually:

```julia
using LifeContingencies, MortalityTables, Plots

tbls = MortalityTables.tables()
tables = [
    tbls["1980 CET - Male Nonsmoker, ANB"],
    tbls["2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB"],
    tbls["2015 VBT Male Non-Smoker RR100 ANB"],
    ]

issue_ages = 30:90
int = InterestRate(0.05)

whole_life_costs = map(tables) do t
    map(issue_ages) do ia
        lc = LifeContingency(
            t.ultimate,
            int,
            ia
            )

        Ax(lc,0) / äx(lc,0)

    end
end

plt = plot(ylabel="Annual Premium per unit", xlabel="Issue Age",
            legend=:topleft, legendfontsize=8)
for (i,t) in enumerate(tables)
    plot!(plt,issue_ages,whole_life_costs[i], label="$(t.d.name)")
end
display(plt)
```
![Comparison of three different mortality tables' effect on insurance cost](https://user-images.githubusercontent.com/711879/79941879-032d9300-842b-11ea-8427-a7dd36fbf2a6.png)


## References

- Life Insurance Mathematics, Gerber
- [Actuarial Mathematics and Life-Table Statistics, Slud](http://www2.math.umd.edu/~slud/s470/BookChaps/Chp6.pdf)
- [Commutation Functions, MacDonald](http://www.macs.hw.ac.uk/~angus/papers/eas_offprints/commfunc.pdf)
