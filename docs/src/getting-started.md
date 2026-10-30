# Getting started

## Install

In Julia's package mode (`]`), install the package and its mortality-table dependency:

```text
pkg> add LifeContingencies MortalityTables
```

This guide targets LifeContingencies 3.0 and Julia 1.10 or newer. Check your installed
versions with `pkg> status`.

## Start with a table you can check by hand

The following rates mean a 50% chance of dying in each of the first two years, followed by
certain death in year three. `start_age=60` makes attained age explicit. All times passed to
LifeContingencies are **durations since issue**, in years.

```@example start
using LifeContingencies, MortalityTables

rates = UltimateMortality([0.5, 0.5, 1.0]; start_age=60)
life = SingleLife(rates)

(issue_age = life.issue_age, omega = omega(life), survival = survival.(life, 0:3))
```

## Add interest with LifeContingency

The `life` supplies mortality and status. To value payments, we also need an interest
assumption. `LifeContingency(life, interest)` keeps those assumptions together:

```@example start
lc = LifeContingency(life, 0.05)
nothing # hide
```

Here `0.05` is an annual effective rate of 5%; a yield curve can be supplied in its place.
The same `lc` can be reused for insurance and annuities. Their constructors will choose
the payments and timing. See [LifeContingency: pairing the assumptions](@ref life-contingency)
for the two constructor styles and how the pair is used.

## Value benefits

Whole life insurance pays one unit at the end of the year of death. The life dies in years
one, two and three with probabilities 0.5, 0.25 and 0.25, so its value is

```math
A = \frac{0.5}{1.05} + \frac{0.25}{1.05^2} + \frac{0.25}{1.05^3}.
```

```@example start
insurance = Insurance(lc)
hand_value = 0.5 / 1.05 + 0.25 / 1.05^2 + 0.25 / 1.05^3
@assert present_value(insurance) ≈ hand_value
present_value(insurance)
```

An annuity due pays while the life is alive, starting now. An immediate annuity starts one
payment period later. A term limits the number of years of cover or payments:

```@example start
(
    whole_life = present_value(insurance),
    two_year_term = present_value(Insurance(lc, 2)),
    annuity_due = present_value(AnnuityDue(lc)),
    annuity_immediate = present_value(AnnuityImmediate(lc)),
)
```

With these rates, the two-year term insurance and the immediate annuity have the same
value. In each of the first two years, mortality is 50%, so dying during the year is as
likely as surviving it. Both products have expected payments of 0.5 at time 1 and 0.25 at
time 2, and neither pays at time 3.

## Inspect the cash flows

`cashflows` returns expected, undiscounted amounts. It already includes benefit probabilities.
The death-benefit rows can be inspected without any actuarial shorthand:

```@example start
[(time = t, probability = p, cashflow = c, discount = v)
 for (t, p, c, v) in zip(timepoints(insurance), probability(insurance), cashflows(insurance), discount(insurance))]
```

## Price premiums and calculate a reserve

`premium_net` sets a level annual premium by equivalence. Premiums are due in advance while
in force; the death benefit is one unit, payable at year end. There are no expenses or profit
loadings in this calculation.

```@example start
premium = premium_net(lc)
@assert premium * present_value(AnnuityDue(lc)) ≈ present_value(insurance)
(premium = premium, year_one_reserve = reserve_premium_net(lc, 1))
```

This is the reserve for a policy still in force at its first anniversary, using the premium
set at issue. Any death benefit for the first year has been settled; the premium due at the
anniversary has not. This differs from `present_value(insurance, 1)`, which does not condition
on survival. [Valuation and reserves](valuation-and-reserves.md) explains the distinction.

## Next steps

- Replace the toy rates with a [select table or a mortality law](mortality-and-lives.md).
- Set [monthly payments, deferral or a guarantee](insurance-and-annuities.md).
- Use [joint lives](joint-lives.md) or a [non-flat yield curve](curves-and-scenarios.md).
- Find exact signatures in the [stable API reference](api.md).
