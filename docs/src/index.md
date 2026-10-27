# LifeContingencies.jl

LifeContingencies computes survival probabilities, life insurance and annuity values, net
premiums and net premium reserves. It combines mortality from
[MortalityTables.jl](https://github.com/JuliaActuary/MortalityTables.jl) with a rate or yield
curve and a payment schedule.

These are the **3.0** docs: Julia **1.10+**, MortalityTables **3**, and FinanceCore **2 or 3**.
If you already use 2.x, start with [Migrating to 3.0](migration.md).

## [Features](@id Features)

- Single and joint lives, with select tables, ultimate tables or parametric mortality.
- Insurance and annuities with terms, payment frequency, deferral and guarantees.
- Net premiums and prospective reserves with explicit status conditioning.
- Flat rates, yield curves and scenario-by-scenario valuation.
- Custom multi-state payments, including recovery and duration-dependent benefits.

## [Getting started](@id Getting-started)

[Getting started](getting-started.md) takes a small mortality table through insurance,
annuities, pricing and a reserve. Then choose a task:

```@raw html
<a id="Constructing-lives"></a>
<a id="When-the-mortality-assumption-runs-out"></a>
<a id="Stochastic-interest-rates"></a>
<a id="Premiums-across-mortality-tables"></a>
<a id="Joint-lives"></a>
<a id="Commutation-and-unexported-function-shorthand"></a>
<a id="Actuarial-notation-shorthand"></a>
<a id="Commutation-functions"></a>
```

| I want to… | Read |
|---|---|
| Use a select table or a mortality law | [Mortality and lives](mortality-and-lives.md) |
| Set payment frequency, deferral or a guarantee | [Insurance and annuities](insurance-and-annuities.md) |
| Value future payments or calculate a reserve | [Valuation and reserves](valuation-and-reserves.md) |
| Value first-to-die or last-survivor benefits | [Joint lives](joint-lives.md) |
| Use a yield curve or run scenarios | [Curves and scenarios](curves-and-scenarios.md) |
| Translate actuarial notation into Julia | [Actuarial notation](actuarial-notation.md) |

## Build a multi-state model

The experimental engine supports payments in states and on transitions, including recovery
and duration-dependent benefits. [Building multi-state models](multi-state-models.md)
starts with three states. The [LTC worked example](ltc.md) adds claim duration, an elimination
period and memory across claims.

The textbook API at the top level is stable. Interfaces in `LifeContingencies.Experimental`
may change in minor releases. Both have dedicated references: [stable](api.md) and
[experimental](experimental-api.md).

## References

- Gerber, *Life Insurance Mathematics*: life insurance, annuities and commutation functions.
- Dickson, Hardy and Waters, *Actuarial Mathematics for Life Contingent Risks*: premiums,
  policy values and multi-state models.
- Slud, [Actuarial Mathematics and Life-Table Statistics](https://www.math.umd.edu/~slud/s470/BookChaps/Chp6.pdf).

Questions or examples to contribute? [Open an issue](https://github.com/JuliaActuary/LifeContingencies.jl/issues).
