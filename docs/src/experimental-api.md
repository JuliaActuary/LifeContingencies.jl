# Experimental API

These interfaces belong to `LifeContingencies.Experimental` and may change in minor releases.
The [model-building guide](multi-state-models.md) explains the data flow and payment phases;
the [LTC example](ltc.md) adds duration and benefit memory.

```@docs
LifeContingencies.Experimental
```

## Model interface

```@docs
LifeContingencies.Experimental.Interval
LifeContingencies.Experimental.transitions
LifeContingencies.Experimental.states
```

## Payment components

A contract is a named tuple of these components. The canonical empty contract is `(;)`.

```@docs
LifeContingencies.Experimental.StatePayment
LifeContingencies.Experimental.TransitionPayment
LifeContingencies.Experimental.CertainPayment
```

## Projection, valuation and conditioning

```@docs
LifeContingencies.Experimental.project
LifeContingencies.Experimental.present_values
LifeContingencies.Experimental.policy_values
LifeContingencies.Experimental.condition
```

## Results

```@docs
LifeContingencies.Experimental.Projection
LifeContingencies.Experimental.PolicyValues
```

## Index

```@index
Modules = [LifeContingencies.Experimental]
```
