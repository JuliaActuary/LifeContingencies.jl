# Joint lives

A `JointLife` combines two `SingleLife`s and a contingency. `Frasier()` models independent
future transitions. It is the only supported dependence assumption.

| Contingency | In force in these states | Death benefit triggers when… |
|---|---|---|
| `LastSurvivor()` (default) | Both alive, or either one alive | The last survivor dies |
| `FirstToDie()` | Both alive | The first death occurs |

The lives keep their own issue ages and mortality selection. An observed dead life stays
dead; a table ending with unknown survival does not establish death.

```@example joint
using LifeContingencies, MortalityTables

life = SingleLife(UltimateMortality([0.5, 0.5, 1.0]; start_age=60))
last_survivor = JointLife(lives=(life, life), contingency=LastSurvivor())
first_to_die = JointLife(lives=(life, life), contingency=FirstToDie())
@assert survival(last_survivor, 1) == 0.75
@assert survival(first_to_die, 1) == 0.25
(last_survivor_probability = survival(last_survivor, 1),
 first_to_die_probability = survival(first_to_die, 1))
```

A joint insurance pays once when its contingency ends; a joint annuity pays while that
contingency remains in force. They use the same product constructors as single lives:

```@example joint
(
    last_death_insurance = present_value(Insurance(last_survivor, 0.05)),
    first_death_insurance = present_value(Insurance(first_to_die, 0.05)),
    last_survivor_annuity = present_value(AnnuityDue(last_survivor, 0.05)),
)
```

## What is known at the valuation date?

For last-survivor business, “the contract is still in force” does not tell you whether one
or both lives are alive. Consider year one in the example above:

| Information at year one | Next-year probability of remaining in force |
|---|---:|
| Only one life known alive | `1/2` |
| Both lives known alive | `3/4` |
| At least one alive, individual statuses unknown | `7/12` |

Conditional on at least one alive at year one, the probabilities of `(alive, alive)`,
`(alive, dead)` and `(dead, alive)` are each `1/3`. The last answer is therefore
``\frac13\frac34+\frac23\frac12=\frac7{12}``.

```@example joint
one_known_alive = survival(life, 1, 2)
both_known_alive = 1 - (1 - one_known_alive)^2
aggregate = survival(last_survivor, 1, 2)
@assert aggregate ≈ 7 / 12
@assert aggregate ≈ both_known_alive / 3 + 2one_known_alive / 3
(one_known_alive = one_known_alive, both_known_alive = both_known_alive,
 unknown_individual_statuses = aggregate)
```

Two-time survival for `JointLife` conditions on its **contingency**, using its original
statuses at issue. It does not assert that both individuals are alive at the starting date.
The conditional joint distribution above is no longer a product of its marginals, even
though subsequent transitions remain independent.

## Reserves from known statuses

The default reserve uses aggregate in-force conditioning. Use `state` to supply the observed
pair at the valuation date instead:

```@example joint
lc = LifeContingency(last_survivor, 0.05)
r = (
    unknown_individual_statuses = reserve_premium_net(lc, 1),
    both_alive = reserve_premium_net(lc, 1; state=(:alive, :alive)),
    only_first_alive = reserve_premium_net(lc, 1; state=(:alive, :dead)),
)
# Each in-force state has probability 1/3 at year one; the two lives are identical.
@assert r.unknown_individual_statuses ≈ r.both_alive / 3 + 2r.only_first_alive / 3
r
```

The state tuple follows the order of `lives`. Passing a state does not reprice the premium
or change the original curve or mortality basis.

## Horizons and assumptions

Last-survivor cover follows the longer life; first-to-die follows the shorter life. An
extinct shorter life stays dead while the longer life continues. Incomplete tables still
need enough support for the contingent payments. Unsupported dependence assumptions raise
an `ArgumentError` rather than silently using independence.

The indicator identity
``S_{\mathrm{first}}(t)+S_{\mathrm{last}}(t)=S_1(t)+S_2(t)``
counts the two individual alive indicators at each date, so it also holds for correlated
starting distributions. Here ``S_1`` and ``S_2`` are the individual survival probabilities.
It gives ``S_{\mathrm{last}}=S_1+S_2-S_{\mathrm{first}}`` and provides a useful check of a
joint model. With the same payment dates and discount factors, the identity also gives
last-survivor life-annuity values from the single-life and first-to-die values. The
[engine guide](multi-state-models.md) shows how distributions and rows are supplied separately.
