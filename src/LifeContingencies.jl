module LifeContingencies

using MortalityTables
using FinanceCore
import FinanceCore: present_value, discount

const mt = MortalityTables

include("engine.jl")
using .Experimental: StatePayment, TransitionPayment, CertainPayment, project, policy_values, condition
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
    decrement(lc::LifeContingency,to_time)
    decrement(lc::LifeContingency,from_time,to_time)

Return the probability of death for the given LifeContingency, with decrements beginning at time zero. 
    
# Examples

```julia-repl
julia> q = [.1,.2,.3,.4];

julia> l = SingleLife(mortality=q);

julia> survival(l,1)
0.9

julia> decrement(l,1)
0.09999999999999998

julia> survival(l,1,2)
0.8

julia> decrement(l,1,2)
0.19999999999999996

julia> survival(l,1,3)
0.5599999999999999

julia> decrement(l,1,3)
0.44000000000000006
```
"""
mt.decrement(lc::LifeContingency, from_time, to_time) = 1 - survival(lc.life, from_time, to_time)


"""
    survival(lc::LifeContingency,from_time,to_time)
    survival(lc::LifeContingency,to_time)

Return the probability of survival for the given LifeContingency, with decrements beginning at time zero. 
    
# Examples

```julia-repl
julia> q = [.1,.2,.3,.4];

julia> l = SingleLife(mortality=q);

julia> survival(l,1)
0.9

julia> decrement(l,1)
0.09999999999999998

julia> survival(l,1,2)
0.8

julia> decrement(l,1,2)
0.19999999999999996

julia> survival(l,1,3)
0.5599999999999999

julia> decrement(l,1,3)
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
