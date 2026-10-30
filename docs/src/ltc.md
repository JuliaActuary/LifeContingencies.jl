# LTC worked example

This academic long-term care model builds on [Building multi-state models](multi-state-models.md).
It adds claim-duration effects, recovery and a second claim, an elimination period (EP),
premium waiver, and a benefit counter retained across claims.

The rates are illustrative, not experience-study estimates. The model is an example in
`examples/ltc_model.jl`, rather than an exported LTC product. Its conventions below are part
of the example's specification.

## Product specification

| Item | Convention |
|---|---|
| Time step | One month, represented as `1/12` year |
| Premium | At the start of each month while healthy; waived on claim |
| Care | One monthly unit when qualified and benefits remain |
| Elimination period | Three completed claim months by default; once satisfied, qualified for life |
| Benefit maximum | 24 full continuing-claim payment months across all claims |
| Recovery or death during a payable month | Half a monthly unit on the exit edge; that half-month does not consume the counter |
| Death benefit | On the death transition, at month end |
| Term | No premium, care or death payments beyond the policy term |

The EP must be completed within one claim. An unqualified recovery resets claim duration;
a qualified recovery retains qualification. The treatment of half-month exit payments is
an approximation, so this counter is not an exact cap on total reimbursed care or money.
The model has no inflation protection, care-setting differences or restoration of benefits.

## State and transition assumptions

Each `LTCState` contains:

| Field | Meaning |
|---|---|
| `status` | `:healthy`, `:claim`, `:dead` or `:lapsed` |
| `claim_months` | Completed months in the current claim (capped; see below) |
| `qualified` | Whether the lifetime EP has already been satisfied |
| `benefit_months` | Full continuing-claim benefit months used across episodes |

Dead and lapsed are absorbing and discard the remaining memory. Claim duration is counted
up to `max(6, elimination_months)`: the six-month rate band must not prevent a longer EP
from qualifying. With EP zero, qualification starts on claim onset.

Default **annual forces**, rather than annual exit probabilities, are listed below.
Here `k` is completed policy years at the start of the month: `k=0` during the first
policy year, `k=1` during the second, and so on.

| Origin | Destination | Force |
|---|---|---|
| Healthy | Claim | 0.02 at issue, multiplied by `exp(0.10*k)` after `k` completed years |
| Healthy | Dead | 0.03 at issue, multiplied by `exp(0.09*k)` |
| Healthy | Lapsed | 0.03 |
| Claim, first six months | Healthy / Dead | 0.60 / 0.25 |
| Claim, later months | Healthy / Dead | 0.20 / 0.15 |

For total exit force ``\mu=\sum_j\mu_j`` over a month, staying has probability
``e^{-\mu/12}``, and exit ``j`` has probability
``\frac{\mu_j}{\mu}(1-e^{-\mu/12})``. Healthy forces change at policy anniversaries.
Only one exit is represented per step; recovery and re-entry take separate monthly steps.
The engine itself does not infer a conversion from annual decrement rates.

## Price a monthly premium

One valuation with a unit monthly premium gives the benefit and premium component values.
Equivalence then sets the premium. This is a finite ten-year policy, so zero terminal value
is justified by maturity.

```@example ltc
using LifeContingencies
include(joinpath(pkgdir(LifeContingencies), "examples", "ltc_model.jl"))

model = LTCModel()
grid = months(10)
unit_contract = ltc_contract(model; term=10, premium=1.0)
unit_values = policy_values(unit_contract, model, 0.04; grid, terminal=0, roots=[HEALTHY])
v = unit_values.before[HEALTHY]
premium = (v.care + v.death) / -v.premium
premium
```

That is a monthly premium per unit of monthly care benefit **and** unit death benefit.
Scaling both benefits to 3,000 gives a premium of about 90 per month:

```@example ltc
(monthly_care_benefit = 3_000, death_benefit = 3_000, monthly_premium = round(3_000 * premium; digits=2))
```

If the death benefit is a different amount, scale its component separately before setting
the premium by equivalence.

## Active-life and claim policy values

These four starts distinguish a new healthy policyholder, a new claim, an ongoing claim
with benefits used, and a recovered life with retained qualification and benefit memory:

```@example ltc
contract = ltc_contract(model; term=10, premium)
starts = [
    HEALTHY,
    LTCState(:claim, 0, false, 0),
    LTCState(:claim, 6, true, 10),
    LTCState(:healthy, 0, true, 10),
]
valued = policy_values(contract, model, 0.04; grid, terminal=0, roots=starts)
@assert isapprox(sum(valued.before[HEALTHY]), 0.0; atol=1e-10)
labels = ("Healthy at issue", "New claim", "Ongoing claim; 10 months used", "Recovered; qualified; 10 months used")
for (label, state) in zip(labels, starts)
    println(label, ": ", round(sum(valued.before[state]); digits=4))
end
```

The healthy value is zero by construction. Other states change both claim eligibility and
remaining benefits. These are policy values **before** current state payments, at the same
policy date and with the same premium fixed at issue.

## Project component cash flows

```@example ltc
projection = project(contract, model; grid, initial=[HEALTHY => 1.0])
pv = present_values(contract, model, 0.04; grid, initial=[HEALTHY => 1.0])
@assert all(isapprox(a, b; atol=1e-10) for (a, b) in zip(pv, valued.before[HEALTHY]))
(expected_care_units = sum(cf.amount for cf in projection.cashflows.care),
 component_pvs = pv)
```

Care units include the half-unit exit payments. Occupancy alone would not capture their
within-month accrual; it is represented by transition payments, including claim self-loops.

## Follow a second claim

A qualified claimant with one full benefit month used recovers. The recovery month pays
half a unit and does not increment the benefit counter. Healthy months keep qualification
and usage. On the next claim the EP is already satisfied:

```@example ltc
first_claim = LTCState(:claim, 4, true, 1)
recovered = LTCState(:healthy, 0, true, 1)
second_claim = LTCState(:claim, 0, true, 1)
next_month = LTCState(:claim, 1, true, 2)
row_has(from, to, interval) = any(first(edge) == to && last(edge) > 0
                                for edge in transitions(model, interval, from))
@assert row_has(first_claim, recovered, Interval(0.0, 1/12))
@assert row_has(recovered, second_claim, Interval(1/12, 2/12))
@assert row_has(second_claim, next_month, Interval(2/12, 3/12))
(recovery_month = contract.care.f(Interval(0.0, 1/12), first_claim, recovered),
 new_claim_month = contract.care.f(Interval(1/12, 2/12), recovered, second_claim),
 continuing_claim_month = contract.care.f(Interval(2/12, 3/12), second_claim, next_month))
```

The payments are `(0.5, 0.0, 1.0)`. Losing either `qualified` or `benefit_months` on recovery
would change the second claim's payments.

## Validation and full source

`test/ltc.jl` checks reduction to SingleLife when incidence and lapse are zero, exhaustive
short-horizon path enumeration, a hand-checked second claim, and 20,000 Monte Carlo paths
within four standard errors. It also checks EP zero and EP longer than the rate band, plus
payments stopping at the term even when the projection grid runs further.

The example uses the same transition rows for all these checks. Its full source is included
below so the rates, memory updates and payment conventions can be inspected together.

```@eval
using Markdown, LifeContingencies
Markdown.MD(Markdown.Code("julia", read(joinpath(pkgdir(LifeContingencies), "examples", "ltc_model.jl"), String)))
```
