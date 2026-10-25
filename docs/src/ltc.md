# Multi-state example: long-term care

`LifeContingencies.Experimental` values contracts on any finite-state model. This page uses
it for an academic long-term care (LTC) model. A policyholder can fall ill, recover, claim
again, lapse or die, and the contract remembers its elimination period and its benefit
maximum across claims.

The model is a worked example, not part of the package API. Its rates are illustrative, not
drawn from any experience study. The code lives in `examples/ltc_model.jl`, and the test
suite runs it.

## The model

**States.** Each state is an `LTCState`, which carries the contract's memory as well as the
policyholder's status:

| Field | Meaning |
|---|---|
| `status` | `:healthy`, `:claim`, `:dead` or `:lapsed` |
| `claim_months` | whole months in the current claim, counted up to 6 |
| `qualified` | whether the elimination period has been satisfied |
| `benefit_months` | benefit months paid so far, across all claims |

**Transitions.** The model moves one month at a time, with constant forces within each
month. Over a month with total force ``\mu``, the probability of staying is
``e^{-\mu/12}``, and exit ``j`` has probability ``\frac{\mu_j}{\mu}\left(1 - e^{-\mu/12}\right)``.

- A healthy life falls ill, dies or lapses:
  - incidence is 2% a year at issue age 75, growing 10% a year
  - mortality is 3% a year, growing 9% a year
  - lapse is 3% a year

  The forces step at each policy anniversary.
- A life on claim recovers or dies:
  - recovery is 60% a year for the first six months of a claim and 20% after
  - mortality is 25% a year for the first six months and 15% after
- Dead and lapsed are absorbing.

**Contract.** `ltc_contract` builds a policy of `term` years with three payments:
- a monthly premium at the start of each month while healthy, waived on claim
- a care benefit for each month on claim once the three-month elimination period is
  satisfied, up to 24 benefit months in total
- a death benefit at the end of the month of death

## Simplifications

The engine needs every convention stated, so here are this model's:

- The elimination period has to be completed within one claim, and once completed it is
  satisfied for life. Real policies often count service days across claims within a window.
- A month that ends in recovery or death is paid as half a month: the proration sits on the
  exit transition. It doesn't count toward the 24-month maximum.
- The benefit maximum counts months, not a pool of money, and there is no inflation
  protection.
- Claim termination depends on claim duration only through two bands, before and after six
  months.
- The dead and lapsed states forget the contract's memory.
- The policy has a finite term, which justifies a terminal value of zero.

## The code

```@eval
using Markdown, LifeContingencies
Markdown.MD(Markdown.Code("julia", read(joinpath(pkgdir(LifeContingencies), "examples", "ltc_model.jl"), String)))
```

## Valuing a policy

The net monthly premium for a ten-year policy balances benefits and premiums for a healthy
life at issue. Every component is linear in the premium, so one valuation with a unit premium
gives it:

```@example ltc
using LifeContingencies
include(joinpath(pkgdir(LifeContingencies), "examples", "ltc_model.jl"))

model = LTCModel()
grid = months(10)
unit = policy_values(ltc_contract(model; term=10, premium=1.0), model, 0.04; grid, terminal=0, roots=[HEALTHY])
v = unit.before[HEALTHY]
premium = (v.care + v.death) / -v.premium
```

Policy values at issue by state give the active-life reserve and the claim reserves from one
calculation. The table covers a healthy life, a new claim, an ongoing claim with 10 benefit
months used, and a healthy life that qualified in an earlier claim and used 10 months:

```@example ltc
contract = ltc_contract(model; term=10, premium)
starts = [HEALTHY, LTCState(:claim, 0, false, 0), LTCState(:claim, 6, true, 10), LTCState(:healthy, 0, true, 10)]
valued = policy_values(contract, model, 0.04; grid, terminal=0, roots=starts)
[state => round(sum(valued.before[state]), digits=4) for state in starts]
```

The healthy life's value is zero by construction. The last life is worth less than a new
policyholder: it skips the elimination period on its next claim, but it has only 14 benefit
months left.

A forward projection gives expected cash flows by component. The expected number of benefit
months paid over the ten years is:

```@example ltc
projection = project(contract, model; grid, initial=[HEALTHY => 1.0])
sum(cf.amount for cf in projection.cashflows.care)
```

## How it is checked

`test/ltc.jl` checks the model in four independent ways:

- **Reduction:** with no incidence and no lapse, the model matches a `SingleLife` on the
  equivalent constant-force table. That covers occupancy, the premium annuity against
  `AnnuityDue(…; frequency=12)`, and the death benefit.
- **Enumeration:** over six months, every value matches brute-force path enumeration.
- **A second claim:** a hand-checked path through a claim, a recovery and a second claim.
  Qualification and the benefit count survive the recovery.
- **Monte Carlo:** 20,000 sampled paths agree with the engine within four standard errors.
