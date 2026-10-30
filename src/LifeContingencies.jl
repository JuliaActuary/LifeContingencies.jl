module LifeContingencies

using MortalityTables
using FinanceCore
import FinanceCore: present_value, discount

const mt = MortalityTables

include("engine.jl")
using .Experimental: StatePayment, TransitionPayment, CertainPayment, project, present_values, policy_values, condition
include("lives.jl")

export LifeContingency,
    Insurance, Endowment, PricedPolicy, policy_value, AnnuityDue, AnnuityImmediate,
    APV,
    SingleLife, Independent, Frasier, JointLife,
    LastSurvivor, FirstToDie,
    survival,
    reserve_premium_net,
    premium_net,
    omega,
    discount,
    benefit,
    probability,
    cashflows,
    timepoints,
    present_value


"""
    LifeContingency(life, interest)

Pair a [`SingleLife`](@ref) or [`JointLife`](@ref) with an interest assumption. A numeric
`interest` is an annual effective rate. A custom yield curve must supply correct values for
FinanceCore's `discount(curve, t)` and `discount(curve, from, to)` methods. For a non-flat
curve, implement interval discounting with the ratio of issue-date factors. Products inherit the original life selection and curve origin from this pair.
Reuse it across products: `Insurance(lc, 2)` and `AnnuityDue(lc, 2)` share the assumptions
but choose different payment rules. Equivalently, pass `(life, interest, ...)` directly to
each product constructor.

```jldoctest
julia> life = SingleLife(UltimateMortality([0.5, 1.0]; start_age=60));

julia> lc = LifeContingency(life, 0.05);

julia> present_value(Insurance(lc, 1))
0.47619047619047616
```
"""
struct LifeContingency{L,Y}
    life::L
    int::Y
end

"""
    omega(lc::LifeContingency)
    omega(l::Life)

The duration in years from issue covered by the mortality assumption. For a rate vector,
survival to this duration uses its last defined rate. For a parametric law it is the time
to the law's own terminal age, possibly fractional or `Inf`. Ending a table does not by
itself establish extinction.

For a `JointLife`, this is the longer horizon for `LastSurvivor` and the shorter for
`FirstToDie`. Each individual still needs support for the transitions being requested.

`omega(rate_vector)` instead gives the last attained age with a rate. With issue age 60 and
rates through age 100, the vector's `omega` is `100` and the life's is `41`.
"""
mt.omega(lc::LifeContingency) = omega(lc.life)

"""
    survival(lc::LifeContingency, to_time)
    survival(lc::LifeContingency, from_time, to_time)

Delegate to `lc.life`'s survival probabilities, with times measured in years from issue.
One-time survival uses the observed status at issue. For a `SingleLife`, two-time survival
is the mortality assumption conditional on being alive at `from_time`; for a `JointLife`,
it conditions on its contingency being active then. See [`SingleLife`](@ref) and
[`JointLife`](@ref). MortalityTables' `decrement` gives the complementary probability.

# Examples

```jldoctest
julia> lc = LifeContingency(SingleLife([0.1, 0.2, 0.3, 0.4]), 0.05);

julia> survival(lc, 1)
0.9

julia> survival(lc, 1, 3)
0.5599999999999999

julia> decrement(lc, 1, 3)
0.44000000000000006
```
"""
mt.survival(lc::LifeContingency, to_time) = survival(lc.life, to_time)
mt.survival(lc::LifeContingency, from_time, to_time) = survival(lc.life, from_time, to_time)

FinanceCore.discount(lc::LifeContingency, t) = discount(lc.int, t)
FinanceCore.discount(lc::LifeContingency, t1, t2) = discount(lc.int, t1, t2)

include("products.jl")
include("textbook.jl")
include("policies.jl")

end # module
