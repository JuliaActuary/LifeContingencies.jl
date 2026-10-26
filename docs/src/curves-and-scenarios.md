# Curves and scenarios

A `LifeContingency` accepts an annual effective rate or any curve implementing FinanceCore's
`discount` interface. The mortality model and the curve retain their issue-date origins.

## A non-flat curve

Install the optional integration package with `pkg> add FinanceModels`. It is a documentation
dependency, not a runtime dependency of LifeContingencies.

```@example curves
using LifeContingencies, MortalityTables
import FinanceModels

quotes = FinanceModels.ZCBYield.([0.03, 0.04, 0.05], [1, 2, 3])
curve = FinanceModels.fit(FinanceModels.Spline.Linear(), quotes, FinanceModels.Fit.Bootstrap())
life = SingleLife(UltimateMortality([0.0, 1.0]; start_age=60))
ins = Insurance(life, curve)
@assert present_value(ins) ≈ discount(curve, 2)
(present_value(ins), present_value(ins, 1))
```

Death occurs in year two with certainty. Its year-one value uses the interval factor
``D(2)/D(1)``:

```@example curves
interval_factor = discount(curve, 2) / discount(curve, 1)
@assert present_value(ins, 1) ≈ interval_factor
@assert !isapprox(interval_factor, discount(curve, 1))
(correct_year_one_value = interval_factor,
 shifted_time_value = discount(curve, 1))
```

With a level rate these two factors happen to agree. With a term structure, subtracting the
valuation date from payment times incorrectly restarts the curve.

## Sensitivity to level rates

Keep the product and mortality assumptions fixed while changing the rate:

```@example curves
sensitivity_life = SingleLife(UltimateMortality([0.1, 0.2, 1.0]; start_age=60))
[(rate=r,
  insurance=present_value(Insurance(sensitivity_life, r)),
  annuity=present_value(AnnuityDue(sensitivity_life, r))) for r in (0.02, 0.04, 0.06)]
```

## Scenario valuation

Each scenario supplies a fixed curve or rate for one complete valuation. A local random
number generator makes this illustration reproducible without changing the global RNG:

```@example curves
using Random
rng = MersenneTwister(2026)
rates = 0.05 .+ 0.01 .* randn(rng, 1_000)
values = [present_value(Insurance(sensitivity_life, r, 2)) for r in rates]
(mean_scenario_value = sum(values) / length(values),
 value_at_mean_rate = present_value(Insurance(sensitivity_life, sum(rates) / length(rates), 2)))
```

Valuation is generally nonlinear in the interest rate, so these two numbers need not
agree. Similarly, the mean of scenario premiums is not in general the ratio of mean benefit
PV to mean premium-annuity PV; those answer different pricing questions.

## Scope of expected-cash-flow discounting

For a fixed curve, value is linear in payments:

```math
\mathbb{E}\!\left[\sum_t d(s,t)C_t\right]
=\sum_t d(s,t)\mathbb{E}[C_t].
```

The package therefore projects expected payments and discounts them. The scenario example
performs this calculation separately within each scenario. A dynamic joint model of
stochastic rates and decrements, such as interest-sensitive lapse, is outside this engine's
current interface; replacing correlated random discount factors with their means does not
preserve the expectation of their product with payments.
