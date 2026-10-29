# LifeContingencies v3.0.0

A breaking release. Lives and products share finite-state transition and payment
interfaces, with linear-time valuation passes. Several long-standing defects are fixed. Contracts that the mortality assumption can't cover now
raise errors instead of being truncated silently.

## Requirements

- Julia 1.10 or newer.
- MortalityTables 3. Its fractional-age assumptions are renamed, so the default `Uniform()`
  is now `UniformDeaths()`. Pass `UniformDeaths()`, `ConstantForce()` or `Balducci()` as
  `fractional_assump`. Fractional survival now composes across intervals.
- FinanceCore 3.
- Transducers is no longer a dependency.

## Breaking changes

### Lives

- **`alive=false`.** It now takes effect: such a life has zero survival and zero state-contingent
  benefit probabilities. Guaranteed installments remain payable.
- **Explicit joint contingency.** Every `JointLife` call must specify `FirstToDie()` or
  `LastSurvivor()`; the former last-survivor default was removed.
- **Joint assumptions.** A `JointLife` with an assumption other than `Independent()`
  (`Frasier()` remains an alias) raises an `ArgumentError`. It used to assume independence silently.
- **Last-survivor horizon.** The horizon follows the longer life rather than the shorter, so
  last-survivor tails are no longer cut off.
- **Joint conditional survival.** `survival(::JointLife, from, to)` raises a `DomainError`
  when the contingency can't be active at `from`, instead of returning 0/0.

### Mortality support

- **Survival past the end of a rate vector.** It is zero once a rate of 1 has established
  extinction. Otherwise it raises a `DomainError` naming the age, where it used to raise a
  `BoundsError`.
- **Contracts past the end of the rates.** A whole-life product, or a term running past the
  end of its rates, needs rates that reach extinction; otherwise it raises a `DomainError`
  instead of truncating silently. Use an explicit term for cover that actually ends, or
  `Endowment(life, interest, n)` when the contract pays on survival to maturity. Maturity
  is a contractual assumption and is never inferred from the table end.
- **Commutation sums.** `N` and `M` reject incomplete mortality and uncovered fractional
  terminal years, consistently with lifetime products.
- **Parametric mortality.** Lifetime products on it need a term. A term may run up to the
  end of the law's domain, which need not fall on a whole year.

### Products

- **Guarantees.**
  - They are counted by installment. A one-year guarantee on an annuity due now covers one
    installment rather than two.
  - `certain=0` means no guarantee, and `certain` defaults to `0` rather than `nothing`.
  - Guarantees continue past established extinction.
- **Zero-duration insurance and annuities.** They keep their life and interest and have empty payment
  streams. They used to become a `ZeroBenefit` with a single zero payment.
- **Invalid parameters** raise an `ArgumentError`:
  - negative or fractional terms
  - a `frequency` that isn't a positive whole number
  - a negative `certain` or `start_time`
- **Vectors instead of lazy iterators.** `survival`, `probability`, `cashflows` and `discount`
  of a product now return vectors.

### Valuation

- **Custom non-flat curves.** Supply `discount(curve, from, to)` as the ratio of the original
  issue-date factors. FinanceCore 3 has no generic interval fallback for custom curves;
  omitting it raises a `MethodError`. Interval factors include the identity `discount(curve, 0, 0) = 1`.
- **`present_value(ins, time)`** discounts with the curve's own interval factors,
  `discount(curve, time, t)`, rather than `discount(curve, t - time)`. Results change on
  non-flat curves and due-annuity payment dates.
- **`reserve_premium_net`** is computed prospectively for an integer anniversary or a
  vector/range of anniversaries. Its equivalence premium is calculated on its supplied basis.
  Impossible default conditioning before termination errors; settled contracts return zero.
  `phase=:before` includes the premium due then (terminal reserve); `:after` settles it
  (initial reserve). It does not accept a stored-premium policy or alternate basis.

### API

- **Exports.** `insurance`, `annuity_due` and `annuity_immediate` are no longer exported;
  they were never defined.
- **Removed:**
  - the unexported `E`; replace `E(lc, t, s)` with `APV(lc, s + t) / APV(lc, s)`
    when the denominator is nonzero
  - the internal types `WholeLife`, `Term` and `ZeroBenefit`, and the annuity payable types
- **`decrement(::LifeContingency, …)`** now comes from MortalityTables' generic fallback, with
  the same results.

## New

- **`Endowment`** pays on death during an explicit positive term or survival to maturity.
- **`PricedPolicy` and `policy_value`** keep benefits, a premium schedule and an established
  premium together. `basis=LifeContingency(...)` changes valuation assumptions while
  retaining that premium. Term, limited-pay, endowment and annuity values are supported;
  vector calls return a numeric column using one occupancy pass and one backward pass,
  with typed state buffers and cached transition rows shared by scalar and column calls.
  This is a retained-premium policy value; it does not recompute a valuation net premium.
- **`premium_net(benefit, premiums)`** prices by equivalence on the products' common basis.
  Premium annuities require `certain=0`.
- **`present_value(product, t; state=...)`** values known single/joint statuses, including
  remaining annuity guarantees after death. Conditional annual death-benefit values require
  anniversaries because alive/dead alone does not describe incurred-but-unpaid claims.
- **`Independent()`** gives independence a descriptive name; `Frasier` remains an alias.
- **Positional joint lives.** `JointLife(l1, l2; contingency=...)` is supported.
- **`FirstToDie()`**, a new joint-life contingency.
- **`reserve_premium_net(lc, t; state=...)`** values a reserve from a known state, such as
  `(:alive, :dead)`.
- **Parametric mortality.** `SingleLife` accepts MortalityTables' parametric laws, with an
  explicit `issue_age`. Its `omega` is the time from issue to the law's own `omega`: `Inf`
  for most laws, and 60.5 for a life aged 40 on a Wittstein law that ends at age 100.5.
- **Broadcasting.** Lives, products and `LifeContingency` broadcast as scalars.
- **`LifeContingencies.Experimental`**, a finite-state engine. It provides `project`,
  `present_values`, `policy_values` and `condition`, and the payment components
  `StatePayment`, `TransitionPayment` and `CertainPayment`. Its interfaces may change in minor
  releases. The documentation includes a long-term care example built on it.

## Fixed

- **Payment-date rounding.** Annuity valuation times within four floating-point ulps of an
  installment date snap to the grid, so expressions such as `0.1*3` do not drop a payment.
- **Input diagnostics.** Invalid age origins and zero premium denominators fail clearly;
  support errors include duration and attained ages. Unbounded `survival(life)` asks for
  explicit finite evaluation dates.
- **Guarantees.** Annuities due counted one too many guaranteed installments, and `certain=0`
  made the first deferred payment certain.
- **Joint lives.**
  - Cash flows after both lives had died were `NaN`.
  - Joint survival inferred `Any`. A joint annuity now takes about two-thirds of the time
    and an eighth of the allocation.
- **Late-duration reserves** lost all precision.
- **Mortality reads** now grow linearly with the projection length, where they grew
  quadratically.
- **`omega`** threw `InexactError` for parametric mortality.
- **Broadcasting** over lives and products threw `MethodError`.
