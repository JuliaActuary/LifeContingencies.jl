# Valuation and reserves

The valuation date and the information known at that date are separate inputs. Moving a
value to year five does not itself establish that the insured is alive at year five.

## Three different quantities

| Operation | Included payments | Information about status |
|---|---|---|
| `present_value(ins)` | All scheduled payments, including issue | Original statuses at issue |
| `present_value(ins, s)` | Outstanding payments at the selected phase, discounted to `s` | Original statuses at issue; no new conditioning |
| `reserve_premium_net(lc, s)` | Future death benefits less premiums, including the premium at `s` | Contract in force at `s`, or an explicit `state` |

The `lc` convenience method is for **whole-life insurance with annual net premiums**.
For term, limited-pay, endowment and annuity contracts, use `PricedPolicy` below.
These are textbook net premium reserves on the issue basis; this function does not implement
statutory CRVM or GAAP LDTI reserve methods. Custom multi-state contracts use the [multi-state engine](multi-state-models.md).

## Issue-date PV and future PV

Let ``\bar c_t = \mathbb{E}_{\pi_0}[C_t]`` be the expected payment at date ``t`` under the
original issue distribution, and ``v(t)`` the issue-date discount factor. The interval factor
is ``v(s,t)=v(t)/v(s)``. Then

```math
\operatorname{PV}_0 = \sum_t v(t)\bar c_t, \qquad
\operatorname{Tail}_s = \sum_{t>s}v(s,t)\bar c_t.
```

The latter is the strict-future value, `present_value(ins, s; phase=:after)`.
The default `phase=:before` also includes annuity-due installments at `s`.
Expected cash flows remain unconditional unless `state` is supplied.

```@example values
using LifeContingencies, MortalityTables

life = SingleLife(UltimateMortality([0.5, 0.5, 1.0]; start_age=60))
lc = LifeContingency(life, 0.0)
ins = Insurance(lc)
@assert cashflows(ins) == [0.5, 0.25, 0.25]
@assert present_value(ins) == 1.0
@assert present_value(ins, 1) == 0.5
(issue_pv = present_value(ins), year_one_tail = present_value(ins, 1))
```

Use `present_value(ins, 1; state=:alive)` for the known-alive value directly.

Only half the original lives reach year one. For this death benefit, at a year-end valuation
date, dividing the tail by survival gives the value conditional on being alive then:

```@example values
conditional_benefit = present_value(ins, 1) / survival(life, 1)
@assert conditional_benefit == 1.0
conditional_benefit
```

This division is justified when every remaining payment requires the contingency to be in
force at `s`. A guaranteed annuity may pay after death; its unconditional tail cannot in
general be converted to a conditional value by dividing by survival.

The cutoff also matters at issue: a due annuity has a payment at time zero, so its one-argument
PV equals `present_value(annuity, 0)`; `phase=:after` excludes the initial payment.

```@example values
annuity = AnnuityDue(lc)
@assert present_value(annuity) == present_value(annuity, 0)
@assert present_value(annuity) - present_value(annuity, 0; phase=:after) == 1.0
(including_issue_payment = present_value(annuity), after_issue_payment = present_value(annuity, 0; phase=:after))
```

## Net premiums

For a unit benefit and annual premiums payable in advance while in force, equivalence gives

```math
P = \frac{A}{\ddot a}.
```

`premium_net(lc)` prices whole life; `premium_net(lc, n)` prices an `n`-year term with
premiums for that term. Multiply by the sum insured to scale the premium.

```@example values
premium = premium_net(lc)
term_premium = premium_net(lc, 2)
@assert premium * present_value(AnnuityDue(lc)) ≈ present_value(Insurance(lc))
(whole_life_premium = premium, two_year_term_premium = term_premium,
 annual_premium_for_100_000 = 100_000 * premium)
```

These are net premiums: benefit and premium cash flows only, with no expenses, commission or
profit margin.

## Policy values and anniversary timing

`reserve_premium_net(lc, s)` establishes the equivalence premium on the supplied basis
and values the **net** future stream prospectively. The time `s` is a nonnegative integer policy duration.

At that anniversary:

1. Death benefits for the year ending at `s` have been paid.
2. The current state is observed or conditioned on.
3. The premium due at `s` is still part of the value.

For a known alive single life, let ``T`` be the future lifetime measured from issue, so
``T>s`` means the life is alive at duration ``s``. The reserve is

```math
V^-_s = \sum_{k\ge1} v(s,s+k)\,\Pr(T\in(s+k-1,s+k]\mid T>s)
       - P\sum_{k\ge0} v(s,s+k)\,\Pr(T>s+k\mid T>s).
```

The sums end with the contract. This is the value **before** the premium due at ``s``,
written ``V^-_s``. Once that premium is received it no longer offsets future benefits, so
``V^+_s=V^-_s+P``. The engine reports both phases as `before` and `after`.

```@example values
reserve = reserve_premium_net(lc, 1)
@assert reserve ≈ reserve_premium_net(lc, 1; state=:alive)
# At zero interest, one unit will be paid on death. Premiums remain at times 1 and 2.
@assert reserve ≈ 1 - premium * (1 + 0.5)
(reserve_before_premium = reserve, reserve_after_premium = reserve + premium)
```

The implementation values that small remaining stream directly, avoiding cancellation
between two almost equal lifetime values. A reserve conditional on being in force is
undefined after the contingency has become impossible; the default conditioning then
throws a `DomainError` while scheduled obligations remain. Pass a range such as
`reserve_premium_net(lc, 0:75)` for a reserve column: each separate call establishes
the equivalence premium anew.

For a joint life, aggregate in-force conditioning and known individual statuses give
different policy values. See [Joint lives](joint-lives.md).

## Curve origin and selection basis

At every valuation date the discount factor is ``v(s,t)=v(t)/v(s)``. Keep the curve's original
origin and the life's original select basis. Using `discount(curve, t-s)` or selecting a new
mortality row at attained age changes the assumptions. The
[curve example](curves-and-scenarios.md) demonstrates the difference numerically.

Product valuation dates within `1e-9 / frequency` years of a scheduled payment snap to that
date (or within four floating-point ulps, if larger), capped below half a payment period.
Insurance and endowments use annual frequency. This keeps dates built by repeated additions
such as `t += 1/12` consistent with the schedule, for premiums and benefits in both phases.
Dates outside this tolerance retain their actual settlement position.

## Establish the policy premium once

A `PricedPolicy` keeps the benefit, premium annuity and established premium together.
Both products share their issue basis. Premium annuities are annualized: monthly premiums
are `premium/12` per installment. Supply `premium=...` when loading an existing policy.

```@example values
term_policy = PricedPolicy(Insurance(lc, 2), AnnuityDue(lc, 2))
@assert term_policy.premium ≈ premium_net(lc, 2)
term_reserves = policy_value(term_policy, 0:3)
@assert abs(first(term_reserves)) < 1e-14
@assert term_reserves[3:4] == [0, 0]
(premium = term_policy.premium, reserves = term_reserves)
```

Use different benefit and premium terms for limited-pay business. This short hand-checkable
example is two-pay whole life. On a complete real mortality basis, `AnnuityDue(lc, 20)`
expresses 20-pay whole life without using the experimental API.

```@example values
limited_pay = PricedPolicy(Insurance(lc), AnnuityDue(lc, 2))
policy_value(limited_pay, 0:3)
```

An explicit endowment maturity also works when the mortality table ends below a rate of one:

```@example values
short_basis = LifeContingency(SingleLife(UltimateMortality([0.1, 0.2]; start_age=60)), 0.05)
endowment_policy = PricedPolicy(Endowment(short_basis, 2), AnnuityDue(short_basis, 2))
@assert abs(policy_value(endowment_policy, 0)) < 1e-14
@assert policy_value(endowment_policy, 2) == 0
policy_value(endowment_policy, 0:3)
```

## Revalue without repricing

A complete `basis=LifeContingency(...)` replaces valuation mortality and interest.
It retains the original age origins, starting statuses, joint contingency and life order.
Contract terms and payment rules remain fixed; lifetime horizons follow the new mortality.
The stored premium remains the premium established on the issue basis.

```@example values
new_basis = LifeContingency(life, 0.03)
stored_premium = term_policy.premium
revalued = policy_value(term_policy, 0:2; basis=new_basis)
@assert term_policy.premium == stored_premium
(issue_basis = term_reserves[1:3], revised_basis = revalued)
```

A column call uses the established premium with one forward occupancy pass and one
backward valuation pass. Single and joint lives use typed fixed-state buffers and cached
transition rows; scalar and column calls share the same calculation. It returns a numeric vector aligned with the supplied integer anniversaries, including
unsorted or repeated requests. Use `state` for a fixed known status across the requested
column. Fractional policy values require additional settlement information and are rejected.

## Guaranteed annuities and observed death

```@example values
guaranteed_benefit = AnnuityDue(lc, 4; certain=3)
payout = PricedPolicy(guaranteed_benefit, AnnuityDue(lc, 1))
@assert policy_value(payout, 1; state=:dead) == 2
@assert policy_value(payout, 1; state=:dead, phase=:after) == 1
policy_value(payout, 1:4; state=:dead)
```

At an annual premium date, `phase=:before` is the **terminal reserve** ``{}_tV``;
`phase=:after` is the **initial reserve** ``{}_tV+P`` when no other beginning-period payment
falls due. End-period death, maturity and immediate-annuity payments at that date have
already settled in both phases. Guarantees remain unconditional during deferral.

A guarantee can outlive all possible survivors. Default active-state conditioning is
then undefined even though guaranteed payments remain; pass `state=:dead` (or
`state=(:dead, :dead)` for joint lives) to value the remaining obligations. A joint
horizon retains both lives' mortality support even if one life was dead at issue, so it
may extend beyond the last possible survivor from the recorded issue statuses. Explicit
observed states can differ from those statuses; the horizon does not change with them.
Once every scheduled obligation has settled, all state choices return zero.

## Established premium versus valuation net premium

`policy_value` retains `policy.premium` when `basis` changes. A supplied premium can be a
contractual or gross amount; the value is still benefits less those premiums, with no
expenses supplied by these unit products. It is not a statutory net premium reserve.
To establish a new equivalence premium on a revised basis, construct a new policy:

```@example values
repriced = PricedPolicy(Insurance(new_basis, 2), AnnuityDue(new_basis, 2))
@assert abs(policy_value(repriced, 0)) < 1e-14
(retained_premium = term_policy.premium, revised_net_premium = repriced.premium)
```

`reserve_premium_net(new_basis, t)` is the whole-life textbook equivalent: its premium is
calculated on `new_basis`. It has no alternate-basis keyword. Neither operation implements
regulatory reserve methodology.

For a single-premium payout annuity, `AnnuityDue(lc, 1)` deliberately represents one
premium at issue. Once that premium is paid, use `present_value(annuity, t; state=:alive)`
for the benefit-only liability, or `policy_value` for the policy's net stream. Premium
annuities require `certain=0`; benefit annuities may still have guaranteed installments.
