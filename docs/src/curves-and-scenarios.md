# Curves and scenarios

A `LifeContingency` accepts an annual effective rate or any curve implementing FinanceCore's
`discount` interface. The mortality model and the curve retain their issue-date origins.
Write the issue-date factor as ``v(t)=\operatorname{discount}(curve,t)`` and the interval
factor as ``v(s,t)=v(t)/v(s)``.

## A non-flat curve

LifeContingencies does not depend on FinanceModels; install it with `pkg> add FinanceModels`
to build fitted curves like this one.

```@example curves
using LifeContingencies, MortalityTables
import FinanceModels

quotes = FinanceModels.ZCBYield.([0.03, 0.04, 0.05], [1, 2, 3])
curve = FinanceModels.fit(FinanceModels.Spline.Linear(), quotes, FinanceModels.Fit.Bootstrap())
life = SingleLife(UltimateMortality([0.0, 1.0]; start_age=60))
ins = Insurance(life, curve)
@assert present_value(ins) ≈ discount(curve, 2)
(issue_pv = present_value(ins), year_one_pv = present_value(ins, 1))
```

Death occurs in year two with certainty. Its year-one value uses the interval factor
``v(2)/v(1)``:

```@example curves
interval_factor = discount(curve, 2) / discount(curve, 1)
@assert present_value(ins, 1) ≈ interval_factor
@assert !isapprox(interval_factor, discount(curve, 1))
(correct_year_one_value = interval_factor,
 shifted_time_value = discount(curve, 1))
```

With a level rate these two factors happen to agree. With a term structure, subtracting the
valuation date from payment times incorrectly restarts the curve.

## [Implement a custom curve](@id custom-curves)

A custom curve must supply correct values for **both** `discount(curve, t)` and
`discount(curve, from, to)`. The first gives the issue-date factor ``v(t)``; the second gives
``v(\mathrm{from},\mathrm{to})=v(\mathrm{to})/v(\mathrm{from})``. Three-argument discounting
is required by the engine, including the identity factor `discount(curve, 0, 0)` when
valuing from issue.

FinanceCore's generic interval method calls `discount(curve, to - from)`. That is correct
for a level rate, but generally restarts a non-flat curve at the wrong origin. A custom
non-flat curve must override that fallback with the ratio of its original factors. With
only the issue-date method, a calculation can run without an error yet return a wrong PV.

Add FinanceCore directly (`pkg> add FinanceCore`) when implementing its interface. Here is
a complete illustrative curve with ``v(t)=\exp(-0.02t-0.005t^2)``:

```@example curves
import FinanceCore
struct ExampleCurve end
FinanceCore.discount(::ExampleCurve, t::Real) = exp(-0.02t - 0.005t^2)
FinanceCore.discount(c::ExampleCurve, from::Real, to::Real) = discount(c, to) / discount(c, from)

custom_curve = ExampleCurve()
custom_insurance = Insurance(life, custom_curve)
@assert discount(custom_curve, 0, 0) == 1
@assert present_value(custom_insurance) ≈ discount(custom_curve, 2)
@assert present_value(custom_insurance, 1) ≈ discount(custom_curve, 2) / discount(custom_curve, 1)
(issue_pv = present_value(custom_insurance), year_one_pv = present_value(custom_insurance, 1))
```

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
scenario_values = [present_value(Insurance(sensitivity_life, r, 2)) for r in rates]
(mean_scenario_value = sum(scenario_values) / length(scenario_values),
 value_at_mean_rate = present_value(Insurance(sensitivity_life, sum(rates) / length(rates), 2)))
```

The gap is small here: rates have a standard deviation of one percentage point and
payments fall within two years. More rate dispersion or more distant payments can make
the gap larger. Valuation is generally nonlinear in the interest rate, so these two
numbers need not agree. Similarly, the mean of scenario premiums is not in general the ratio of mean benefit
PV to mean premium-annuity PV; those answer different pricing questions.

## Scope of expected-cash-flow discounting

For a fixed curve, value is linear in payments:

```math
\mathbb{E}\!\left[\sum_t v(s,t)C_t\right]
=\sum_t v(s,t)\mathbb{E}[C_t].
```

The package therefore projects expected payments and discounts them. The scenario example
performs this calculation separately within each scenario. A dynamic joint model of
stochastic rates and decrements, such as interest-sensitive lapse, is outside this engine's
current interface; replacing correlated random discount factors with their means does not
preserve the expectation of their product with payments.
