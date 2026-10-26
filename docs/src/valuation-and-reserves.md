# Valuation and reserves

The valuation date and the information known at that date are separate inputs. Moving a
value to year five does not itself establish that the insured is alive at year five.

## Three different quantities

| Operation | Included payments | Information about status |
|---|---|---|
| `present_value(ins)` | All scheduled payments, including issue | Original statuses at issue |
| `present_value(ins, s)` | Payments strictly **after** `s`, discounted to `s` | Original statuses at issue; no new conditioning |
| `reserve_premium_net(lc, s)` | Future death benefits less premiums, including the premium at `s` | Contract in force at `s`, or an explicit `state` |

The reserve convenience function is for **whole-life insurance with annual net premiums**.
For other payment structures, construct a net contract in the
[multi-state engine](multi-state-models.md).

## Issue-date PV and future PV

Let ``\bar c_t = \mathbb{E}_{\pi_0}[C_t]`` be the expected payment at date ``t`` under the
original issue distribution, and ``D(t)`` the issue-date discount factor. Then

```math
\operatorname{PV}_0 = \sum_t D(t)\bar c_t, \qquad
\operatorname{Tail}_s = \sum_{t>s}\frac{D(t)}{D(s)}\bar c_t.
```

The latter is `present_value(ins, s)`. Its expected cash flows remain unconditional on any
new information at `s`.

```@example values
using LifeContingencies, MortalityTables

life = SingleLife(UltimateMortality([0.5, 0.5, 1.0]; start_age=60))
lc = LifeContingency(life, 0.0)
ins = Insurance(lc)
@assert cashflows(ins) == [0.5, 0.25, 0.25]
@assert present_value(ins) == 1.0
@assert present_value(ins, 1) == 0.5
(present_value(ins), present_value(ins, 1))
```

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
PV includes a payment that `present_value(annuity, 0)` excludes.

```@example values
annuity = AnnuityDue(lc)
@assert present_value(annuity) - present_value(annuity, 0) == 1.0
(present_value(annuity), present_value(annuity, 0))
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
(premium, term_premium, annual_premium_for_100_000 = 100_000 * premium)
```

These are net premiums: benefit and premium cash flows only, with no expenses, commission or
profit margin.

## Policy values and anniversary timing

`reserve_premium_net(lc, s)` keeps the premium fixed at issue and values the **net** future
stream prospectively. The time `s` is a nonnegative integer policy duration.

At that anniversary:

1. Death benefits for the year ending at `s` have been paid.
2. The current state is observed or conditioned on.
3. The premium due at `s` is still part of the value.

For a known alive single life, the reserve is

```math
V^-_s = \sum_{k\ge1} d(s,s+k)\,\Pr(T\in(s+k-1,s+k]\mid T>s)
       - P\sum_{k\ge0} d(s,s+k)\,\Pr(T>s+k\mid T>s).
```

The sums end with the contract. This is a value **before** the current premium, denoted
``V^-``. Immediately after paying that premium the insurer's liability increases by ``P``.
The engine exposes both phases as `before` and `after`.

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
throws a `DomainError`.

For a joint life, aggregate in-force conditioning and known individual statuses give
different policy values. See [Joint lives](joint-lives.md).

## Curve origin and selection basis

At every valuation date the discount factor is ``d(s,t)=D(t)/D(s)``. Keep the curve's original
origin and the life's original select basis. Using `discount(curve, t-s)` or selecting a new
mortality row at attained age changes the assumptions. The
[curve example](curves-and-scenarios.md) demonstrates the difference numerically.
