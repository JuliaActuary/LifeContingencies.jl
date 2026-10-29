# Stable API

The top-level textbook API is stable. Start with the [user guide](getting-started.md) for
worked calculations; see the [experimental reference](experimental-api.md) for custom models.

```@meta
CurrentModule = LifeContingencies
```

## Lives and assumptions

See [Mortality and lives](mortality-and-lives.md) and [Joint lives](joint-lives.md).

```@docs
SingleLife
JointLife
LifeContingency
Independent
Frasier
LastSurvivor
FirstToDie
omega
survival
```

## Products and their views

See [Insurance and annuities](insurance-and-annuities.md) for amounts, dates and guarantees.

```@docs
Insurance
Endowment
AnnuityDue
AnnuityImmediate
timepoints
benefit
probability
cashflows
discount
```

## Values, premiums and reserves

See [Valuation and reserves](valuation-and-reserves.md) for conditioning and payment phases.

```@docs
present_value
NetPremiumPolicy
premium_net
reserve_premium_net
APV
```

## Actuarial notation

These commutation functions are available with an explicit import. `D` is an alias of
`APV`; `A`, `ä`, `a`, `P`, `V`, `v` and `ω` map to the functions in the
[notation guide](actuarial-notation.md).

```@docs
LifeContingencies.l
LifeContingencies.D
LifeContingencies.C
LifeContingencies.N
LifeContingencies.M
```

## Index

```@index
Modules = [LifeContingencies]
```
