# Migrating to 3.0

3.0 preserves the public textbook constructor names and rebuilds their probability and
valuation calculations over a shared finite-state engine. Where results change, 3.0 is
correcting them; each change is listed below. Use this guide alongside [NEWS](https://github.com/JuliaActuary/LifeContingencies.jl/blob/master/NEWS.md).

## Environment and fractional assumptions

| 2.x | 3.0 |
|---|---|
| Julia 1.6 floor | Julia 1.10 or newer |
| MortalityTables 2 | MortalityTables 3 |
| `Uniform()` | `UniformDeaths()` |
| `Constant()` | `ConstantForce()` |
| `Balducci()` | `Balducci()` |

FinanceCore 3 is required. Transducers is no longer a direct dependency. Rename
explicit fractional-assumption arguments as well as any imports. Historical 2.x snippets
on this page illustrate the old API and are not run by the documentation build.

```julia
# 2.x
SingleLife(rates; fractional_assump=Uniform())
```

```@example upgrade
using LifeContingencies, MortalityTables
rates = UltimateMortality([0.5, 0.5, 1.0]; start_age=60)
life = SingleLife(rates; fractional_assump=UniformDeaths())
survival(life, 0.5)
```

Conditional fractional survival now composes consistently. Recheck fractional-age reference
values rather than retaining results from the earlier conditional formulas.

## Products and guarantees

| Old behavior | New behavior and action |
|---|---|
| Due guarantee included one extra installment | `certain*f` guaranteed installments; check due-annuity results |
| `certain=0` could guarantee a deferred first payment | Zero guarantees none |
| `certain=nothing` used for no guarantee | Omit it or pass `certain=0` |
| Zero term produced an internal `ZeroBenefit` | Empty stream, PV zero; use the public views instead of inspecting concrete types |
| Invalid parameters could fail during projection | Invalid term, frequency, guarantee or deferral errors at construction |

The guarantee remains unconditional during deferral, and it continues after extinction or
observed death. This is separate from survival:

```@example upgrade
lc = LifeContingency(life, 0.0)
@assert probability(AnnuityDue(lc, 3; certain=1)) == [1.0, 0.5, 0.25]
@assert probability(AnnuityDue(lc, 2; start_time=1, certain=0)) == [0.5, 0.25]
@assert isempty(cashflows(Insurance(lc, 0)))
(zero_term_pv = present_value(Insurance(lc, 0)),
 guaranteed_annuity_cashflows = cashflows(AnnuityDue(lc, 3; certain=1)))
```

Product `survival`, `probability`, `cashflows` and `discount` views now return vectors;
`timepoints` remains a range. Downstream code depending on iterator types must adapt.

## Mortality support and statuses

| Change | Action |
|---|---|
| `alive=false` takes effect | Expect zero survival and state-contingent benefits; guarantees remain payable |
| Last-survivor horizon follows the longer life | Recheck joint-life tails previously cut off |
| Only `Frasier()` is implemented | Other joint assumptions now error instead of silently using independence |
| Conditional joint survival at an impossible in-force date errors | Handle a `DomainError` instead of a `NaN` |
| A rate vector ending below 1 is incomplete | Supply longer rates, or an explicit supported term |

Appending a terminal rate of 1 imposes certain death in that last year; it is an assumption
change, not a neutral way to fix an incomplete table. Choose a term if cover actually ends
with the available data:

```@example upgrade
short = SingleLife(UltimateMortality([0.1, 0.2]; start_age=60))
# Whole life on `short` errors: survival after the known rates is unspecified.
present_value(Insurance(short, 0.05, 2))
```

`omega(life)` is duration from issue, whereas `omega(rate_vector)` is the last attained age
with a rate. Parametric lives require an explicit issue age and textbook products need a
supported term. Their horizon can be infinite or fractional; do not blindly cast it to `Int`.
See [Mortality support](@ref mortality-support).

## Future PVs and reserves

`present_value(ins, s)` now includes annuity-due installments at `s`; end-period payments
have settled. Pass `phase=:after` for the old strict-future cutoff. It retains the issue
distribution unless `state` is supplied.
It now discounts using `discount(curve, s, t)`. Results change on non-flat curves where the
old shifted-time discount factors differed. It remains an unconditional tail, not a
conditional reserve.

**Custom non-flat curves need their own interval method.** If your 2.x extension defines only
`FinanceCore.discount(curve, t)`, add
`FinanceCore.discount(curve, from, to) = discount(curve, to) / discount(curve, from)` for
your curve type, using its existing issue-date factors. FinanceCore 3 has no generic interval fallback for custom curves: omitting the method raises a `MethodError`.
The engine uses interval discounting even for issue-date valuation, including the identity
factor `discount(curve, 0, 0)`. See the
[runnable custom-curve example](@ref custom-curves).

`reserve_premium_net` now values the remaining net stream prospectively. Its anniversary
convention is unchanged: deaths through `s` settled, premium at `s` included. It takes an
integer duration and retains the issue premium. Late-duration results can change because
the old subtraction lost precision.

```@example upgrade
lc_interest = LifeContingency(life, 0.05)
(unconditional_tail = present_value(Insurance(lc_interest), 1),
 in_force_reserve = reserve_premium_net(lc_interest, 1),
 known_alive_reserve = reserve_premium_net(lc_interest, 1; state=:alive))
```

Joint reserves condition on the contingency alone by default. Use `state=(:alive, :dead)`
or another observed pair when individual statuses are known. See [Joint lives](joint-lives.md).

## Names and extension code

The unexported internal types `WholeLife`, `Term`, `ZeroBenefit` and annuity payable types were removed;
use constructors and documented views.

The unexported `E(lc, t, s)` was removed. Replace it with
`APV(lc, s + t) / APV(lc, s)`, provided the denominator is nonzero. Here `s` is a duration
from issue, not an attained age. This is the conditional pure endowment over the next `t`
years, on the original mortality and curve basis:

```@example upgrade
s, t = 1, 1
conditional_endowment = APV(lc_interest, s + t) / APV(lc_interest, s)
@assert conditional_endowment ≈ survival(life, s, s+t) * discount(lc_interest, s, s+t)
conditional_endowment
```

The exports `insurance`, `annuity_due` and `annuity_immediate` were removed because those names were
never defined.

## New

- `FirstToDie()` adds first-death joint-life benefits.
- Lives, products and `LifeContingency` now broadcast as scalars.
- `LifeContingencies.Experimental` adds the finite-state engine.

For the experimental engine, import its interfaces
explicitly, and expect possible changes in minor releases. Start with
[Building multi-state models](multi-state-models.md), rather than extending the old product
hierarchy's death-benefit defaults.

### Additional 3.0 conventions

- Every `JointLife` call must specify `contingency=FirstToDie()` or `contingency=LastSurvivor()`.
- `Independent()` names the independence assumption; `Frasier` remains an alias.
- `N` and `M` now reject incomplete mortality and uncovered partial terminal years.
- `Endowment(lc, n)` expresses explicit maturity without changing mortality rates.
- `present_value(product, t; state=...)` values known statuses, including dead annuitants with guarantees.
