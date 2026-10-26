# Actuarial notation

The descriptive API is exported by default. Short actuarial names are available through an
explicit import or a qualified call, so that common variable names such as `a` and `P`
remain available in your own code.

## [Aliases](@id notation-aliases)

| Name | Operation |
|---|---|
| `A(lc, args...)` | `present_value(Insurance(lc, args...))` |
| `ä(lc, args...; kwargs...)` | `present_value(AnnuityDue(lc, args...; kwargs...))` |
| `a(lc, args...; kwargs...)` | `present_value(AnnuityImmediate(lc, args...; kwargs...))` |
| `P` | `premium_net` |
| `V` | `reserve_premium_net` |
| `v` | `discount` |
| `ω` | `omega` |

```@example notation
using LifeContingencies, MortalityTables
using LifeContingencies: A, ä, a, P, V, v, ω

lc = LifeContingency(SingleLife(UltimateMortality([0.5, 0.5, 1.0]; start_age=60)), 0.05)
@assert A(lc, 2) ≈ present_value(Insurance(lc, 2))
@assert ä(lc) ≈ present_value(AnnuityDue(lc))
(A(lc), ä(lc), a(lc), P(lc), V(lc, 1), v(lc, 1), ω(lc))
```

## [Commutation formulas](@id commutation-formulas)

The arguments to these functions are **policy durations**. For issue age ``x``, put
``p(t)={}_tp_x``, ``D_0(t)=\operatorname{discount}(lc.int,t)``, and
``H=\lfloor\operatorname{omega}(lc)\rfloor``. The package uses a unit radix by default:

| Function | Implemented quantity |
|---|---|
| `l(lc, t; basis=1.0)` | ``\mathrm{basis}\,p(t)`` |
| `APV(lc, t)` | ``p(t)D_0(t)`` |
| `D(lc, t)` | Alias of `APV(lc, t)` |
| `C(lc, t)` | ``D_0(t+1)[p(t)-p(t+1)]`` |
| `N(lc, s)` | ``\sum_{t=s}^{H-1}D(lc,t)`` |
| `M(lc, s)` | ``\sum_{t=s}^{H-1}C(lc,t)`` |

`APV(lc,t)` is the survival-weighted discount factor for a unit survival payment at `t`.
To value a complete insurance or annuity, use its product constructor and `present_value`.
Changing `basis` in `l` scales that call only; it does not change the life or other
commutation functions.

```@example notation
using LifeContingencies: l, D, C, N, M

@assert D(lc, 1) == APV(lc, 1)
@assert N(lc, 0) ≈ present_value(AnnuityDue(lc))
@assert M(lc, 0) ≈ present_value(Insurance(lc))
[(t=t, lives=l(lc, t; basis=1_000), D=D(lc, t), C=C(lc, t)) for t in 0:2]
```

These sums stop at the last whole year covered by the mortality assumption. They are not
a continuation of an incomplete table, and infinite-horizon laws have no finite terminal
sum. Use an explicitly termed product for that calculation. Incomplete tables and fractional
terminal ages also mean that the sums need not represent a complete lifetime obligation.
