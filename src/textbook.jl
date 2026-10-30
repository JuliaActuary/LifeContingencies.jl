###################
## COMMUTATIONS ###
###################

"""
    APV(lc::LifeContingency, time)

The survival-weighted issue-date discount factor `survival(lc, time) * discount(lc, time)`.
This is the unit pure endowment ``{}_tE_x`` for a single life issued at age ``x``, with
`time` measured in years from issue. It is also
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
    iszero(survival(lc, floor(Int, ω))) || throw(beyond_assumption(lc.life, ω))
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
from issue and the radix is one. Infinite support raises a `DomainError`; incomplete or uncovered fractional
terminal support raises a `DomainError`. Import `M` explicitly.
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
MortalityTables.survival(ins::Endowment) = in_force_at(ins.life, 0:ins.term-1)
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
benefit(ins::Union{DeathBenefit,Endowment}) = 1.0
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
timepoints(ins::Endowment) = 1:ins.term
timepoints(ins::Annuity) = schedule(ins).times

"""
    present_value(ins::Insurance)

The actuarial present value at issue of every scheduled benefit, including any payment at
time zero. Expected payments use the original life statuses, and the curve is fixed for
the valuation. A zero-duration product is worth zero. The two-argument method uses the selected settlement phase at its valuation date.
"""
function FinanceCore.present_value(ins::Insurance)
    (; contract, grid) = unit_payments(ins)
    return benefit(ins) * sum(value_from_issue(contract, ins.life, ins.int, grid))
end

"""
    present_value(ins::Insurance, time::Real; state=nothing, phase=:before)

The actuarial present value of the given insurance benefits, as if you were standing at `time`:
the expected outstanding payments as projected from issue, discounted to `time`
with the curve's own factors `discount(interest, time, t)`.

For example, if the given `Insurance` has *decremented* payments `[1,2,3,4,5]` at times `[1,2,3,4,5]` and you call `pv(ins,3)`,
you will get the present value of the payments `[4,5]` at times `[4,5]`, discounted to time 3.

At `phase=:before`, end-period benefits (including immediate-annuity installments) have
settled but beginning-period annuity-due installments remain. `phase=:after` also settles
due installments. For a net stream with only an annual premium due, these correspond to
the terminal reserve and initial reserve respectively; they differ from the engine
phases, which apply before/after every state payment. In both phases, valuation times
within `1e-9 / frequency` years of a scheduled payment are snapped to its date (or within
four floating-point ulps, if larger), capped below half a payment period. Death insurance
and endowments use annual frequency. This also covers date drift from repeated additions
in projection loops. Pass `state` for a known current status;
otherwise the value retains the issue distribution. Dividing by the survivorship
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
function FinanceCore.present_value(ins::Insurance, time::Real; state=nothing, phase=:before)
    check_valuation(time, phase, ins.life, state)
    time = valuation_time(ins, time)
    isnothing(state) || return conditional_product_value(ins, time, state, phase)
    cfs = cashflows(ins)
    include_now = is_due(ins) && phase === :before
    return sum((cf * discount(ins.int, time, t) for (cf, t) in zip(cfs, timepoints(ins)) if t > time || (include_now && t == time)); init=zero(eltype(cfs)))
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
    return equivalence_premium(A(lc), ä(lc))
end

premium_net(lc::LifeContingency, to_time) = equivalence_premium(A(lc, to_time), ä(lc, to_time))

function equivalence_premium(benefits, premiums)
    iszero(premiums) && throw(DomainError(premiums, "the premium annuity has zero present value; an equivalence premium is undefined"))
    return benefits / premiums
end

function reserve_premium_net end

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
