# LifeContingencies v3.0.0

A breaking release. Lives and products are now valued by one linear-time engine. Several
long-standing defects are fixed. Contracts that the mortality assumption can't cover now
raise errors instead of being truncated silently.

## Requirements

- Julia 1.10 or newer.
- MortalityTables 3. Its fractional-age assumptions are renamed, so the default `Uniform()`
  is now `UniformDeaths()`. Pass `UniformDeaths()`, `ConstantForce()` or `Balducci()` as
  `fractional_assump`. Fractional survival now composes across intervals.
- FinanceCore 2 or 3.
- Transducers is no longer a dependency.

## Breaking changes

### Lives

- **`alive=false`.** It now takes effect: such a life has zero survival and zero state-contingent
  benefit probabilities. Guaranteed installments remain payable.
- **Joint assumptions.** A `JointLife` with an assumption other than `Frasier()` raises an
  `ArgumentError`. It used to assume independence silently.
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
  instead of truncating silently. Give such contracts a term that ends with the rates, for
  example `Insurance(life, interest, omega(life))`.
- **Parametric mortality.** Lifetime products on it need a term. A term may run up to the
  end of the law's domain, which need not fall on a whole year.

### Products

- **Guarantees.**
  - They are counted by installment. A one-year guarantee on an annuity due now covers one
    installment rather than two.
  - `certain=0` means no guarantee, and `certain` defaults to `0` rather than `nothing`.
  - Guarantees continue past established extinction.
- **Zero-duration products.** They keep their life and interest and have empty payment
  streams. They used to become a `ZeroBenefit` with a single zero payment.
- **Invalid parameters** raise an `ArgumentError`:
  - negative or fractional terms
  - a `frequency` that isn't a positive whole number
  - a negative `certain` or `start_time`
- **Vectors instead of lazy iterators.** `survival`, `probability`, `cashflows` and `discount`
  of a product now return vectors.

### Valuation

- **Custom curves.** Implement both `discount(curve, t)` and `discount(curve, from, to)`.
  An issue-date method alone no longer suffices; interval factors use the ratio of the
  original factors, including `discount(curve, 0, 0) = 1`.
- **`present_value(ins, time)`** discounts with the curve's own interval factors,
  `discount(curve, time, t)`, rather than `discount(curve, t - time)`. Results change on
  non-flat curves only.
- **`reserve_premium_net`** is computed prospectively and takes an integer `time`. As before,
  it conditions on the contract being in force at `time`. Results change only where the old
  subtraction lost precision.

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
