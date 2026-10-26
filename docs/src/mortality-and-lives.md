# Mortality and lives

A `SingleLife` fixes the mortality assumption, original issue age, fractional-age assumption
and observed status at issue. Revaluing that life later keeps its original selection basis.
It does not select a new mortality-table row at the valuation date.

## Select and ultimate tables

```@example mortality
using LifeContingencies, MortalityTables

vbt = MortalityTables.table("2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB")
selected = SingleLife(vbt.select[30])
same_selection = SingleLife(vbt.select; issue_age=30)
ultimate = SingleLife(vbt.ultimate; issue_age=60)
@assert selected.mortality == same_selection.mortality
(selected.issue_age, ultimate.issue_age, survival(selected, 10))
```

Pass a rate vector, a select table's vector of rows, or a supported parametric law. Passing
the entire `MortalityTable` is ambiguous; choose its select or ultimate data first. Rate-vector
indices are attained ages. For an ordinary Julia vector the first index is `1`; set up an
age-indexed `UltimateMortality` when attained age matters.

## Durations, ages and fractional survival

For a life issued at age ``x``, `survival(life, t)` evaluates survival to age ``x+t``. The
two-time form `survival(life, s, t)` is conditional survival for a life alive at duration `s`.
Use `decrement(life, s, t)` from MortalityTables for its complement.

```@example mortality
q = UltimateMortality([0.1, 0.2, 1.0]; start_age=60)
l = SingleLife(q)
(survival(l, 1), survival(l, 1, 2), decrement(l, 1, 2))
```

Fractional times use `UniformDeaths()` by default. Alternatives are `ConstantForce()` and
`Balducci()`:

```@example mortality
[(string(typeof(a)), survival(SingleLife(q; fractional_assump=a), 0.5))
 for a in (UniformDeaths(), ConstantForce(), Balducci())]
```

MortalityTables 3 derives conditional fractional survival consistently with the underlying
survival function. On supported intervals these probabilities compose:

```@example mortality
@assert survival(l, 0, 0.5) * survival(l, 0.5, 1.5) ≈ survival(l, 0, 1.5)
survival(l, 0, 1.5)
```

## Observed status

`alive=false` means the life is dead at its reference date. Its one-time survival is zero.
The two-time form still describes the mortality assumption for a life *alive at the starting
time*. It does not infer an observed status there.

```@example mortality
dead = SingleLife(q; alive=false)
@assert survival(dead, 1) == 0
@assert survival(dead, 0, 1) == survival(l, 0, 1)
(survival(dead, 1), survival(dead, 0, 1))
```

State-contingent annuity payments then vanish, but [guaranteed payments](insurance-and-annuities.md)
remain payable. Joint lives can combine different observed statuses.

## [Mortality support](@id mortality-support)

`omega(life)` is the duration covered by the mortality assumption. It is not generally an
age, and reaching it does not by itself prove extinction.

| Assumption | What is known at its end? | Product consequence |
|---|---|---|
| Rate vector reaching a rate of 1 | The life is dead after that rate's year | Dead is an established absorbing continuation |
| Rate vector ending below 1 | Survival beyond support is unknown | Contingent payments needing that support error |
| Parametric law | Support follows the law's domain, possibly infinite or fractional | Give textbook products an explicit supported term |

A vector whose last rate is at age 100 covers the year beginning at 100. For issue age 60,
its life horizon is `100 - 60 + 1 = 41`. A parametric law instead uses its own terminal age
without the extra year.

```@example mortality
incomplete = SingleLife(UltimateMortality([0.1, 0.2]; start_age=60))
@assert omega(incomplete) == 2
present_value(Insurance(incomplete, 0.05, 2))
```

That two-year term makes the contract's end explicit. Whole life on the same rates is
undefined:

```@example mortality
try
    present_value(Insurance(incomplete, 0.05))
catch err
    @assert err isa DomainError
    sprint(showerror, err)
end
```

Supply a longer or complete rate vector when a contingent obligation extends further.
Certain payments can be valued past mortality support because they do not require survival.
In the multi-state engine, a projection horizon and a terminal value must also state what
happens to obligations remaining at the horizon.

## Parametric mortality

```@example mortality
gompertz = SingleLife(MortalityTables.Gompertz(a=0.0002, b=0.13); issue_age=40)
(omega(gompertz), present_value(Insurance(gompertz, 0.05, 10)))
```

Most laws have infinite support. Some, such as Wittstein, have finite support whose end need
not be a whole attained age. Choose terms and payment dates covered by the law; an integer
annual death-benefit term must fit its entire last year within that support.

## [Compare tables](@id comparing-tables)

Keep issue ages and the interest assumption fixed when comparing premiums:

```@example mortality
tables = [
    MortalityTables.table("1980 CET - Male Nonsmoker, ANB"),
    vbt,
]
[(table=t.metadata.name,
  premiums=[premium_net(LifeContingency(SingleLife(t.ultimate; issue_age=age), 0.05))
            for age in 30:10:60]) for t in tables]
```
