###################
## COMMUTATIONS ###
###################

"""
    D(lc::LifeContingency, to_time)

``D_x`` is a retrospective actuarial commutation function which is the product of the survival and discount factor.
"""
function D(lc::LifeContingency, to_time)
    return discount(lc.int, to_time) * survival(lc, to_time)
end


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
    discount(lc.int, to_time + 1) * (l(lc, to_time) - l(lc, to_time + 1))

end

"""
    N(lc::LifeContingency, from_time)

``N_x`` is a prospective actuarial commutation function which is the sum of the `D` (``D_x``) values from the given time to the end of the mortality table.
"""
function N(lc::LifeContingency, from_time)
    range = from_time:(omega(lc)-1)
    vals = Iterators.map(from_time -> D(lc, from_time), range)
    return sum(vals)
end

"""
    M(lc::LifeContingency, from_time)

The ``M_x`` actuarial commutation function where the `from_time` argument is `x`.
Issue age is based on the issue_age in the LifeContingency `lc`.
"""
function M(lc::LifeContingency, from_time)
    range = from_time:omega(lc)-1
    vals = Iterators.map(from_time -> C(lc, from_time), range)
    return sum(vals)
end

E(lc::LifeContingency, t, x) = D(lc, x + t) / D(lc, x)

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
MortalityTables.survival(ins::DeathBenefit) = expected_payments(ins).survival
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
probability(ins::DeathBenefit) = expected_payments(ins).probability
probability(ins::Annuity) = expected_payments(ins)


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
function FinanceCore.present_value(ins::T) where {T<:Insurance}
    cfs = cashflows(ins)
    times = timepoints(ins)
    yield = ins.int
    pv = present_value(yield, cfs, times)
    return pv
end

"""
    present_value(Insurance,`time`)

The actuarial present value of the given insurance benefits, as if you were standing at `time`. 

For example, if the given `Insurance` has *decremented* payments `[1,2,3,4,5]` at times `[1,2,3,4,5]` and you call `pv(ins,3)`, 
you will get the present value of the payments `[4,5]` at times `[1,2]`.

To get an undecremented present value, divide by the survivorship to that timepoint:

```julia
present_value(ins,10) / survival(ins,10)
```
"""
function FinanceCore.present_value(ins::T, time) where {T<:Insurance}
    ts = timepoints(ins)
    times = (t - time for t in ts if t > time)
    cfs = (cf for (cf, t) in zip(cashflows(ins), ts) if t > time)
    yield = ins.int
    pv = present_value(yield, cfs, times)
    return pv
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
     reserve_premium_net(lc::LifeContingency,time)

The net premium reserve at the end of year `time`.
"""
function reserve_premium_net(lc::LifeContingency, time)
    PVFB = A(lc) - A(lc, time)
    PVFP = premium_net(lc) * (ä(lc) - ä(lc, time))
    return (PVFB - PVFP) / APV(lc, time)
end

"""
    APV(lc::LifeContingency,to_time)

The **actuarial present value** which is the survival times the discount factor for the life contingency.
"""
function APV(lc::LifeContingency, to_time)
    return survival(lc, to_time) * discount(lc.int, to_time)
end

# unexported aliases
const V = reserve_premium_net
const v = FinanceCore.discount
# A(args) = present_value(Insurance(args))
# a(args, kwargs) = present_value(AnnuityImmediate(args...; kwargs...))
# ä(args) = present_value(AnnuityDue(args))
const A = FinanceCore.present_value ∘ Insurance
const a = FinanceCore.present_value ∘ AnnuityImmediate
const ä = FinanceCore.present_value ∘ AnnuityDue
const P = premium_net
const ω = omega
