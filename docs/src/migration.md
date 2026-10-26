# Migrating to 3.0

3.0 preserves the public textbook constructor names and rebuilds their probability and
valuation calculations over a shared finite-state engine. Observable corrections are
intentional; use this guide alongside [NEWS](https://github.com/JuliaActuary/LifeContingencies.jl/blob/master/NEWS.md).

## Environment and fractional assumptions

| 2.x | 3.0 |
|---|---|
| Julia 1.6 floor | Julia 1.10 or newer |
| MortalityTables 2 | MortalityTables 3 |
| `Uniform()` | `UniformDeaths()` |
| `Constant()` | `ConstantForce()` |
| `Balducci()` | `Balducci()` |

FinanceCore 2 and 3 are supported. Transducers is no longer a direct dependency. Rename
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
(present_value(Insurance(lc, 0)), cashflows(AnnuityDue(lc, 3; certain=1)))
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

`present_value(ins, s)` still excludes payments at `s` and retains the issue distribution.
It now discounts using `discount(curve, s, t)`. Results change on non-flat curves where the
old shifted-time discount factors differed. It remains an unconditional tail, not a
conditional reserve.

`reserve_premium_net` now values the remaining net stream prospectively. Its anniversary
convention is unchanged: deaths through `s` settled, premium at `s` included. It takes an
integer duration and retains the issue premium. Late-duration results can change because
the old subtraction lost precision.

```@example upgrade
lc_interest = LifeContingency(life, 0.05)
(present_value(Insurance(lc_interest), 1),
 reserve_premium_net(lc_interest, 1),
 reserve_premium_net(lc_interest, 1; state=:alive))
```

Joint reserves condition on the contingency alone by default. Use `state=(:alive, :dead)`
or another observed pair when individual statuses are known. See [Joint lives](joint-lives.md).

## Names and extension code

`FirstToDie()` and scalar broadcasting for lives and products are available. The unexported
internal types `WholeLife`, `Term`, `ZeroBenefit` and annuity payable types were removed;
use constructors and documented views. The unexported `E` was removed. The exports
`insurance`, `annuity_due` and `annuity_immediate` were removed because those names were
never defined.

`LifeContingencies.Experimental` adds the finite-state engine. Import its interfaces
explicitly, and expect possible changes in minor releases. Start with
[Building multi-state models](multi-state-models.md), rather than extending the old product
hierarchy's death-benefit defaults.
