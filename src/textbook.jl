###################
## COMMUTATIONS ###
###################

"""
    APV(lc::LifeContingency, time)

The survival-weighted issue-date discount factor `survival(lc, time) * discount(lc, time)`.
This values a unit survival payment at `time`, measured in years from issue. It is also
available as the unexported commutation function `D`. To value a complete product, use
[`present_value`](@ref) with [`Insurance`](@ref) or an annuity constructor.
"""
function APV(lc::LifeContingency, to_time)
    return survival(lc, to_time) * discount(lc.int, to_time)
end

"""
    D(lc::LifeContingency, to_time)

The unit-radix commutation function: another name for [`APV`](@ref). Its time argument is
policy duration, not attained age.
"""
const D = APV

"""
    l(lc::LifeContingency, to_time)

Expected survivors at policy duration `to_time`, equal to `basis * survival(lc, to_time)`.
The default radix is one. `basis` scales this call only; it does not change the life or
other commutation functions. Import `l` explicitly from LifeContingencies.
"""
function l(lc::LifeContingency, to_time; basis=1.0)
    return survival(lc.life, to_time) * basis
end

"""
    C(lc::LifeContingency, to_time)

The issue-date value of a unit death benefit for the year starting at policy duration
`to_time`: `discount(lc, to_time + 1) * (survival(lc, to_time) - survival(lc, to_time + 1))`.
Import `C` explicitly from LifeContingencies.
"""
function C(lc::LifeContingency, to_time)
    return discount(lc.int, to_time + 1) * (l(lc, to_time) - l(lc, to_time + 1))
end

# Commutation sums run through the last whole year the mortality assumption covers.
function last_table_year(lc::LifeContingency)
    ω = omega(lc)
    isinf(ω) && throw(DomainError(ω, "commutation sums run to the end of the mortality table, and parametric mortality defined at every age has none"))
    return floor(Int, ω) - 1
end

"""
    N(lc::LifeContingency, from_time)

Sum `D(lc, t)` for `t` in `from_time:(floor(Int, omega(lc)) - 1)`. Durations are in years
from issue and the radix is one. Infinite support raises a `DomainError`; this sum does not
supply a continuation for incomplete mortality. Import `N` explicitly.
"""
N(lc::LifeContingency, from_time) = sum(t -> D(lc, t), from_time:last_table_year(lc); init=zero(APV(lc, 0)))

"""
    M(lc::LifeContingency, from_time)

Sum `C(lc, t)` for `t` in `from_time:(floor(Int, omega(lc)) - 1)`. Durations are in years
from issue and the radix is one. Infinite support raises a `DomainError`; a fractional
terminal age leaves its final partial year outside the sum. Import `M` explicitly.
"""
M(lc::LifeContingency, from_time) = sum(t -> C(lc, t), from_time:last_table_year(lc); init=zero(APV(lc, 0)))

"""
    survival(ins::Insurance, time)

The probability that the product's life contingency is in force at duration `time`, given
its original status at issue. This is independent of the product's guarantee or schedule.

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
    discount(ins::Insurance)

A vector of issue-date discount factors at `timepoints(ins)`. These factors contain no
mortality probabilities. For revaluation, use the curve's interval factors via
[`present_value`](@ref).
"""
FinanceCore.discount(ins::Insurance) = [discount(ins.int, t) for t in timepoints(ins)]


"""
    benefit(ins::Insurance)

The scheduled unit amount: `1.0` for death insurance and `1.0 / frequency` for an annuity.
Thus an annuity is normalized to one annual unit, regardless of payment frequency.
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
    cashflows(ins::Insurance)

A vector of expected, undiscounted amounts, `benefit(ins) .* probability(ins)`, dated at
[`timepoints`](@ref). Mortality has already been applied; do not multiply by survival again.
An empty product has an empty vector. Scale these amounts or the product PV to change the
sum insured or annual annuity amount.
"""
function cashflows(ins::I) where {I<:Insurance}
    b = benefit(ins)
    return [p * b for p in probability(ins)]
end


"""
    timepoints(ins::Insurance)

A range of scheduled payment times in years from issue, aligned with [`cashflows`](@ref).
Death insurance pays at year ends. Annuity dates depend on commencement, frequency and
due/immediate timing. `collect(timepoints(ins))` materializes a vector.
"""
timepoints(ins::DeathBenefit) = 1:benefit_years(ins)
timepoints(ins::Annuity) = schedule(ins).times

"""
    present_value(ins::Insurance)

The actuarial present value at issue of every scheduled benefit, including any payment at
time zero. Expected payments use the original life statuses, and the curve is fixed for
the valuation. A zero-duration product is worth zero. The two-argument method instead
excludes payments on its valuation date.
"""
function FinanceCore.present_value(ins::Insurance)
    (; contract, grid) = unit_payments(ins)
    return benefit(ins) * sum(value_from_issue(contract, ins.life, ins.int, grid))
end

"""
    present_value(ins::Insurance, time::Real)

The actuarial present value of the given insurance benefits, as if you were standing at `time`:
the expected payments strictly after `time`, as projected from issue, discounted to `time`
with the curve's own factors `discount(interest, time, t)`.

For example, if the given `Insurance` has *decremented* payments `[1,2,3,4,5]` at times `[1,2,3,4,5]` and you call `pv(ins,3)`,
you will get the present value of the payments `[4,5]` at times `[4,5]`, discounted to time 3.

This is not a value for a life known to be in force at `time`. Dividing by the survivorship
gives one only when every remaining payment depends on being in force at `time`, as for a
life annuity outside its guarantee period, or a death benefit valued at the end of a policy
year:

```jldoctest
julia> ins = Insurance(SingleLife(UltimateMortality([0.5, 0.5, 1.0])), 0.0);

julia> cashflows(ins)
3-element Vector{Float64}:
 0.5
 0.25
 0.25

julia> present_value(ins, 1)                     # the payments at times 2 and 3
0.5

julia> present_value(ins, 1) / survival(ins, 1)  # for a life in force at time 1
1.0
```
"""
function FinanceCore.present_value(ins::Insurance, time::Real)
    cfs = cashflows(ins)
    return sum((cf * discount(ins.int, time, t) for (cf, t) in zip(cfs, timepoints(ins)) if t > time); init=zero(eltype(cfs)))
end

"""
    premium_net(lc::LifeContingency)
    premium_net(lc::LifeContingency,to_time)

The level annual net premium for one unit of whole-life insurance, or term insurance
through `to_time` years. Benefits are payable at the end of the year of death; premiums are
payable in advance while the contingency is in force, for the same term. Equivalence gives
insurance PV divided by annuity-due PV. Expenses and profit loadings are excluded.

For a sum insured of `B`, multiply the result by `B`. A reserve uses the premium set at
issue; calling this function again on a newly selected attained-age life reprices it.
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
