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
lc = LifeContingency(life, 0.05)

life.issue_age, omega(life), survival.(life, 0:3)
```

`LifeContingency` pairs the life with its interest assumption. A numeric rate such as `0.05`
is an annual effective rate. A curve can be supplied in its place.

## Value benefits

Life insurance pays a unit at the end of the year of death. The probabilities here are
`[0.5, 0.25, 0.25]`, so its value is

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

## Inspect the cash flows

`cashflows` returns expected, undiscounted amounts. It already includes benefit probabilities.
The death-benefit rows can be inspected without any actuarial shorthand:

```@example start
collect(zip(timepoints(insurance), probability(insurance), cashflows(insurance), discount(insurance)))
```

The columns are payment time, probability of payment, expected payment and discount factor.

## Price premiums and calculate a reserve

`premium_net` sets a level annual premium by equivalence. Premiums are due in advance while
in force; the death benefit is one unit, payable at year end. There are no expenses or profit
loadings in this calculation.

```@example start
premium = premium_net(lc)
@assert premium * present_value(AnnuityDue(lc)) ≈ present_value(insurance)
(premium = premium, year_one_reserve = reserve_premium_net(lc, 1))
```

The reserve is conditional on being in force at year one. Death benefits through that date
are settled; the premium at year one has yet to be paid. The premium remains the one set at
issue. See [Valuation and reserves](valuation-and-reserves.md) before using a future PV as a
reserve.

## Next steps

- Replace the toy rates with a [select table or a mortality law](mortality-and-lives.md).
- Set [monthly payments, deferral or a guarantee](insurance-and-annuities.md).
- Use [joint lives](joint-lives.md) or a [non-flat yield curve](curves-and-scenarios.md).
- Find exact signatures in the [stable API reference](api.md).
