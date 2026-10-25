###################
## COMMUTATIONS ###
###################

"""
    APV(lc::LifeContingency,to_time)

The **actuarial present value** which is the survival times the discount factor for the life contingency.
"""
function APV(lc::LifeContingency, to_time)
    return survival(lc, to_time) * discount(lc.int, to_time)
end

"""
    D(lc::LifeContingency, to_time)

``D_x`` is a retrospective actuarial commutation function which is the product of the survival and discount factor: another name for [`APV`](@ref).
"""
const D = APV

"""
    l(lc::LifeContingency, to_time)

``l_x`` is a retrospective actuarial commutation function which is the survival up to a certain point in time. By default, will have a unitary basis (ie `1.0`), but you can specify `basis` keyword argument to use something different (e.g. `1000` is common in the literature.)
"""
function l(lc::LifeContingency, to_time; basis=1.0)
    return survival(lc.life, to_time) * basis
end

"""
    C(lc::LifeContingency, to_time)

``C_x`` is a retrospective actuarial commutation function which is the product of the discount factor and the difference in `l` (``l_x``).
"""
function C(lc::LifeContingency, to_time)
    return discount(lc.int, to_time + 1) * (l(lc, to_time) - l(lc, to_time + 1))
end

# Commutation sums run through the last year the mortality rates cover.
function last_table_year(lc::LifeContingency)
    ω = omega(lc)
    isinf(ω) && throw(DomainError(ω, "commutation sums run to the end of the mortality table, and parametric mortality has none"))
    return Int(ω) - 1
end

"""
    N(lc::LifeContingency, from_time)

``N_x`` is a prospective actuarial commutation function which is the sum of the `D` (``D_x``) values from the given time to the end of the mortality table.
"""
N(lc::LifeContingency, from_time) = sum(t -> D(lc, t), from_time:last_table_year(lc); init=zero(APV(lc, 0)))

"""
    M(lc::LifeContingency, from_time)

``M_x`` is a prospective actuarial commutation function which is the sum of the `C` (``C_x``) values from the given time to the end of the mortality table.
"""
M(lc::LifeContingency, from_time) = sum(t -> C(lc, t), from_time:last_table_year(lc); init=zero(APV(lc, 0)))

"""
    survival(Insurance,time)

The survivorship for the given insurance from time zero to `time`.

"""
function MortalityTables.survival(ins::I, t) where {I<:Insurance}
    survival(ins.life, t)
end

"""
    survival(Insurance)

The survivorship vector for the given insurance: for life insurance, the probability of being
in force at the start of each year of cover; for an annuity, at each payment time.
"""
MortalityTables.survival(ins::DeathBenefit) = in_force_at(ins.life, 0:benefit_years(ins)-1)
MortalityTables.survival(ins::Annuity) = in_force_at(ins.life, timepoints(ins))


"""
    discount(Insurance)

The discount vector for the given insurance.
"""
FinanceCore.discount(ins::Insurance) = [discount(ins.int, t) for t in timepoints(ins)]


"""
    benefit(Insurance)

The unit benefit for the given insurance.
"""
benefit(ins::DeathBenefit) = 1.0
benefit(ins::Annuity) = 1.0 / ins.frequency


"""
    probability(Insurance)

The vector of contingent benefit probabilities for the given insurance: for life insurance,
the probability that the benefit is paid at the end of each year of cover; for an annuity, the
probability that each installment is paid (one for guaranteed installments).
"""
probability(ins::Insurance) = expected_payments(ins)


"""
    cashflows(Insurance)

The vector of decremented benefit cashflows for the given insurance.
"""
function cashflows(ins::I) where {I<:Insurance}
    b = benefit(ins)
    return [p * b for p in probability(ins)]
end


"""
    timepoints(Insurance)

The vector of times corresponding to the cashflow vector for the given insurance.
"""
timepoints(ins::DeathBenefit) = 1:benefit_years(ins)
timepoints(ins::Annuity) = schedule(ins).times

"""
    present_value(Insurance)

The actuarial present value of the given insurance benefits.
"""
function FinanceCore.present_value(ins::Insurance)
    (; contract, grid) = unit_payments(ins)
    return benefit(ins) * sum(value_from_issue(contract, ins.life, ins.int, grid))
end

"""
    present_value(Insurance,`time`)

The actuarial present value of the given insurance benefits, as if you were standing at `time`:
the expected payments strictly after `time`, as projected from issue, discounted to `time`
with the curve's own factors `discount(interest, time, t)`.

For example, if the given `Insurance` has *decremented* payments `[1,2,3,4,5]` at times `[1,2,3,4,5]` and you call `pv(ins,3)`,
you will get the present value of the payments `[4,5]` at times `[4,5]`, discounted to time 3.

This is not a value for a life known to be in force at `time`. Dividing by the survivorship
gives one only when every remaining payment depends on being in force at `time`, as for a
life annuity outside its guarantee period, or a death benefit valued at the end of a policy
year:

```julia
present_value(ins,10) / survival(ins,10)
```
"""
function FinanceCore.present_value(ins::Insurance, time::Real)
    cfs = cashflows(ins)
    return sum((cf * discount(ins.int, time, t) for (cf, t) in zip(cfs, timepoints(ins)) if t > time); init=zero(eltype(cfs)))
end

"""
    premium_net(lc::LifeContingency)
    premium_net(lc::LifeContingency,to_time)

The net premium for a whole life insurance (without second argument) or a term life insurance through `to_time`.

The net premium is based on 1 unit of insurance with the death benfit payable at the end of the year and assuming annual net premiums.
"""
function premium_net(lc::LifeContingency)
    return A(lc) / ä(lc)
end

premium_net(lc::LifeContingency, to_time) = A(lc, to_time) / ä(lc, to_time)

"""
     reserve_premium_net(lc::LifeContingency, time; state=nothing)

The net premium reserve at the end of year `time` for whole life insurance with annual net
premiums: the value at `time` of future death benefits less future net premiums. The death
benefits of the year ending at `time` have been paid; the premium due at `time` has not. The
premium is the one set at issue, `premium_net(lc)`.

By default the reserve is for a contract still in force at `time`, given each life's status at
issue; for a `JointLife` that conditions on the joint contingency alone, not on which lives
are alive. Pass `state` to value it from a known state instead: `:alive` for a `SingleLife`,
or a pair of statuses such as `(:alive, :dead)` for a `JointLife`. Throws a `DomainError` when
the contract cannot be in force at `time`.
"""
function reserve_premium_net(lc::LifeContingency, time::Integer; state=nothing)
    life = lc.life
    time >= 0 || throw(ArgumentError("`time` must be nonnegative; got $time"))
    isnothing(state) || state in Experimental.states(life) ||
        throw(ArgumentError("`state` must be one of $(Experimental.states(life)); got $state"))
    premium = premium_net(lc)
    contract = (
        benefit=death_payment(life),
        premium=StatePayment((t, s) -> active(life, s) ? -premium : zero(premium)),
    )
    initial = isnothing(state) ? in_force_distribution(life, time) : [state => one(probability_type(life))]
    T = promote_type(value_type(life, lc.int), typeof(premium))
    grid = time:benefit_years(Insurance(lc))
    values = policy_values(contract, life, lc.int; grid, terminal=0, roots=first.(initial), numbertype=T)
    return sum(p * sum(values.before[s]) for (s, p) in initial)
end

# The distribution of states at `time` among contracts still in force, given each life's status at issue.
function in_force_distribution(life, time)
    at_time = project_from_issue((;), life, 0:time).final
    return condition(at_time, s -> active(life, s))
end

# Lives, products and life contingencies act as scalars in broadcasting.
Base.broadcastable(x::Union{Life,Insurance,LifeContingency}) = Ref(x)

# unexported aliases
const V = reserve_premium_net
const v = FinanceCore.discount
const A = FinanceCore.present_value ∘ Insurance
const a = FinanceCore.present_value ∘ AnnuityImmediate
const ä = FinanceCore.present_value ∘ AnnuityDue
const P = premium_net
const ω = omega
