module LifeContingencies

using MortalityTables
using FinanceCore
import FinanceCore: present_value, discount

const mt = MortalityTables

include("engine.jl")
using .Experimental: StatePayment, TransitionPayment, CertainPayment, project, present_values, policy_values, condition
include("lives.jl")

export LifeContingency,
    Insurance, AnnuityDue, AnnuityImmediate,
    APV,
    SingleLife, Frasier, JointLife,
    LastSurvivor, FirstToDie,
    survival,
    reserve_premium_net,
    insurance,
    annuity_due,
    annuity_immediate,
    premium_net,
    omega,
    survival,
    discount,
    benefit,
    probability,
    cashflows,
    cashflows,
    timepoints,
    present_value





"""
    struct LifeContingency
        life::Life
"""
struct LifeContingency{L,Y}
    life::L
    int::Y
end

Base.broadcastable(lc::LifeContingency) = Ref(lc)

"""
    omega(lc::LifeContingency)
    omega(l::Life)

The number of years from issue that the mortality assumption covers: survival to `omega` uses the last defined rate. For parametric mortality, it is the time from issue to the law's own `omega`, the last age at which the law is defined, which need not be a whole number of years; for most laws it is `Inf`. A `JointLife` lasts as long as its contingency can be active: the longer life's `omega` for `LastSurvivor`, and the shorter life's for `FirstToDie`.

This differs from `omega` of a mortality vector, which is the last attained age with a rate. For example, with issue age 60 and rates through age 100, `omega` of the vector is `100` and `omega` of the life is `41`.
"""
mt.omega(lc::LifeContingency) = omega(lc.life)

"""
    survival(lc::LifeContingency, to_time)
    survival(lc::LifeContingency, from_time, to_time)

The survival probabilities of `lc`'s life. With one time, the probability that the life is
alive at `to_time`, given its status at issue. With two, the probability of surviving from
`from_time` to `to_time` for a life alive at `from_time`. `decrement` gives the complementary
probabilities of death.

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

end # module
