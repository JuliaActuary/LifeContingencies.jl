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

`alive` records what is known about the person at **issue, time zero**. Here that is age 60.
`alive=true` means the person is alive then; mortality determines whether they survive later.
`alive=false` means they are already dead then, so their probability of being alive at any
future time is zero. This flag supplies a starting state, not a new mortality table.

The two forms of `survival` answer different questions:

| Call | Question | Uses the recorded `alive` status? |
|---|---|---|
| `survival(life, t)` | Given this person's status at issue, what is the probability they are alive at `t`? | Yes |
| `survival(life, s, t)` | Under this mortality assumption, what is the probability of reaching `t` **if alive at `s`**? | No: it explicitly assumes an alive starting state |

The rates `q` above have first-year mortality of 10%, so an alive person's first-year
survival probability is 90%. Compare two lives with the same rates and different starting
statuses:

```@example mortality
living = SingleLife(q)  # alive=true by default
dead = SingleLife(q; alive=false)
@assert survival(dead, 1) == 0
@assert survival(dead, 0, 1) == survival(living, 0, 1)
(
    from_alive_at_issue = survival(living, 1),
    from_dead_at_issue = survival(dead, 1),
    if_alive_at_start = survival(dead, 0, 1),
)
```

The answers are `0.9`, `0.0` and `0.9`. The last value is a hypothetical query of the
**mortality assumption**. It does not say that this dead person can become alive, and it
does not change their recorded status. In particular, it is not obtained by conditioning
the dead person's actual projection on an impossible alive event.

Use the one-time form for a person's survival from their recorded starting status. Use the
two-time form when you explicitly want mortality conditional on an alive starting state.
This distinction describes `SingleLife`; joint-life two-time survival conditions on the
joint contingency, as explained in [Joint lives](joint-lives.md).

### Effect on payments

Product valuation starts from the recorded status. A life annuity on `dead` therefore pays
nothing, even though a hypothetical alive-start mortality query can return `0.9`.
[Guaranteed installments](insurance-and-annuities.md) remain payable because they do not
require the person to be alive:

```@example mortality
life_annuity = AnnuityDue(dead, 0.0, 2)
guaranteed_annuity = AnnuityDue(dead, 0.0, 2; certain=1)
@assert cashflows(life_annuity) == [0.0, 0.0]
@assert cashflows(guaranteed_annuity) == [1.0, 0.0]
(life_annuity = cashflows(life_annuity), one_year_guarantee = cashflows(guaranteed_annuity))
```

An observed dead status is also useful for a last-survivor contract where one insured has
already died. The joint life then starts with one dead person and one living person; its
survival depends only on the remaining life:

```@example mortality
one_survivor = JointLife(lives=(dead, living))
@assert survival(one_survivor, 1) == survival(living, 1)
survival(one_survivor, 1)
```

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
