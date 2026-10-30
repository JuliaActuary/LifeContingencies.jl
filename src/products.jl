##################
### Insurances ###
##################

abstract type Insurance end

function LifeContingency(ins::I) where {I<:Insurance}
    LifeContingency(ins.life, ins.int)
end

## Each product is a contract of unit payment components for the experimental engine:
## `unit_payments(ins)` gives the contract and the grid to project it over, from each life's
## status at issue. Views collect its projection; present values fold it.

project_from_issue(contract, life, grid) =
    project(contract, life; grid, initial=initial_distribution(life), numbertype=probability_type(life))

value_from_issue(contract, life, curve, grid) =
    present_values(contract, life, curve; grid, initial=initial_distribution(life), numbertype=value_type(life, curve))

probability_type(life) = typeof(last(only(initial_distribution(life))))
# Values take the number types of the probabilities and of the curve's factors, read at issue:
# a valuation from issue discounts from there, whatever its term.
value_type(life, curve) = promote_type(probability_type(life), typeof(discount(curve, 0, 0)))

death_payment(life) = TransitionPayment((interval, from, to) -> active(life, from) && !active(life, to) ? 1 : 0)

# A unit at each of `dates`, which are sorted, while the life is in force.
in_force_payment(life, dates) = StatePayment((t, state) -> active(life, state) && insorted(t, dates) ? 1 : 0)

# Grid times from issue through `dates`, which are sorted and nonnegative.
from_issue(dates) = !isempty(dates) && iszero(first(dates)) ? dates : [zero(eltype(dates)); dates]

beyond_assumption(t) = DomainError(t,
    "the contract continues past the end of the mortality assumption at time $t while lives remain in force; supply rates that reach extinction (a rate of 1), or give the contract a shorter term")

checked_term(::Nothing) = nothing
function checked_term(term::Integer)
    term >= 0 || throw(ArgumentError("a term must be nonnegative; got $term"))
    return Int(term)
end
checked_term(term) = throw(ArgumentError("a term must be a whole number of years, or `nothing` for life; got $term"))

struct DeathBenefit{L,Y} <: Insurance
    life::L
    int::Y
    term::Union{Nothing,Int}
end

"""
    Insurance(lc::LifeContingency[, term])
    Insurance(life, interest[, term])

Life insurance paying a unit benefit at the end of the year of death, for `term` years, or for
the whole of life when `term` is omitted. For a `JointLife`, the benefit is paid at the end of
the year in which its contingency ends. A `term` of zero gives an insurance with no payments.

The mortality assumption has to cover the contract. Whole-life insurance needs rates that reach
extinction (a rate of 1), so give a `term` for a table whose rates stop short of 1, or for
parametric mortality.

Issue age is based on the `issue_age` in the LifeContingency `lc`. `interest` is a rate such as
`0.05`, or any yield curve that FinanceCore can discount with, such as one from FinanceModels.

# Examples

```jldoctest
julia> life = SingleLife(UltimateMortality([0.5, 1.0]));   # the rates reach 1, so whole life is defined

julia> present_value(Insurance(life, 0.05, 1))   # one-year term
0.47619047619047616

julia> present_value(Insurance(life, 0.05))      # whole life
0.9297052154195011
```
"""
Insurance(life, int, term=nothing) = DeathBenefit(life, int, checked_term(term))
Insurance(lc::LifeContingency, args...) = Insurance(lc.life, lc.int, args...)

# The years a death benefit runs: its term, ending early at the last whole year the mortality
# assumption covers. It may stop there only if no life remains in force.
function benefit_years(ins::DeathBenefit)
    horizon = omega(ins.life)
    isnothing(ins.term) && isinf(horizon) &&
        throw(DomainError(horizon, "parametric mortality never reaches extinction, so a whole-life insurance needs a `term`"))
    covered = isinf(horizon) ? ins.term : floor(Int, horizon)
    years = isnothing(ins.term) ? covered : min(ins.term, covered)
    continues = isnothing(ins.term) || ins.term > years
    continues && !iszero(survival(ins.life, years)) && throw(beyond_assumption(horizon))
    return years
end

unit_payments(ins::DeathBenefit) = (contract=(benefit=death_payment(ins.life),), grid=0:benefit_years(ins))

abstract type AnnuityKind end
struct Due <: AnnuityKind end
struct Immediate <: AnnuityKind end

struct Annuity{L,Y,K<:AnnuityKind} <: Insurance
    life::L
    int::Y
    kind::K
    term::Union{Nothing,Int}
    certain::Int
    start_time::Int
    frequency::Int
end

function annuity(kind, life, int, term; certain, start_time, frequency)
    frequency isa Integer && frequency >= 1 ||
        throw(ArgumentError("`frequency` must be a positive whole number of payments a year; got $frequency"))
    certain isa Integer && certain >= 0 ||
        throw(ArgumentError("`certain` must be a nonnegative whole number of years; got $certain"))
    start_time isa Integer && start_time >= 0 ||
        throw(ArgumentError("`start_time` must be a nonnegative whole number of years; got $start_time"))
    return Annuity(life, int, kind, checked_term(term), Int(certain), Int(start_time), Int(frequency))
end

"""
    AnnuityDue(lc::LifeContingency[, term]; certain=0, start_time=0, frequency=1)
    AnnuityDue(life, interest[, term]; certain=0, start_time=0, frequency=1)

An annuity due: `frequency` payments a year of `1/frequency` each, at the start of each period,
beginning at `start_time` and lasting `term` years, or for life when `term` is omitted.

The first `certain` years of payments are guaranteed: they are paid whether or not the life
survives, including during any deferral. Later payments are made only while the life (or a
`JointLife`'s contingency) is in force. A `term` of zero gives an annuity with no payments.

The mortality assumption has to cover the life-contingent payments. A life annuity needs rates
that reach extinction (a rate of 1), so give a `term` for a table whose rates stop short of 1,
or for parametric mortality.

# Examples

```jldoctest
julia> life = SingleLife(UltimateMortality([0.5, 1.0]));

julia> present_value(AnnuityDue(life, 0.05))             # 1 now, and 1 a year later if alive
1.4761904761904763

julia> present_value(AnnuityDue(life, 0.05; certain=2))  # both payments guaranteed
1.9523809523809523

julia> collect(timepoints(AnnuityDue(life, 0.05, 1; frequency=4)))
4-element Vector{Float64}:
 0.0
 0.25
 0.5
 0.75
```
"""
AnnuityDue(life, int, term=nothing; certain=0, start_time=0, frequency=1) =
    annuity(Due(), life, int, term; certain, start_time, frequency)
AnnuityDue(lc::LifeContingency, args...; kwargs...) = AnnuityDue(lc.life, lc.int, args...; kwargs...)

"""
    AnnuityImmediate(lc::LifeContingency[, term]; certain=0, start_time=0, frequency=1)
    AnnuityImmediate(life, interest[, term]; certain=0, start_time=0, frequency=1)

An annuity immediate: like [`AnnuityDue`](@ref), but each payment is made at the end of its
period.

# Examples

```jldoctest
julia> life = SingleLife(UltimateMortality([0.5, 1.0]));

julia> present_value(AnnuityImmediate(life, 0.05))   # 1 at the end of each year while alive
0.47619047619047616
```
"""
AnnuityImmediate(life, int, term=nothing; certain=0, start_time=0, frequency=1) =
    annuity(Immediate(), life, int, term; certain, start_time, frequency)
AnnuityImmediate(lc::LifeContingency, args...; kwargs...) = AnnuityImmediate(lc.life, lc.int, args...; kwargs...)

# How many periods after `start_time` the first payment falls.
first_period(::Due) = 0
first_period(::Immediate) = 1

# Installment k is paid at start_time + (k - 1 + first_period) / frequency. Counting
# installments in whole numbers keeps the schedule exact at any frequency.
function schedule(ins::Annuity)
    horizon = omega(ins.life)
    in_term = isnothing(ins.term) ? nothing : ins.term * ins.frequency
    isnothing(in_term) && isinf(horizon) &&
        throw(DomainError(horizon, "parametric mortality never reaches extinction, so a life annuity needs a `term`"))
    guaranteed = isnothing(in_term) ? ins.certain * ins.frequency : min(ins.certain * ins.frequency, in_term)
    step = 1 / ins.frequency
    first_date = ins.start_time + first_period(ins.kind) * step
    # enough installment dates for the term, or to pass the end of the mortality assumption
    available = isnothing(in_term) ? max(0, ceil(Int, (horizon - first_date) * ins.frequency) + 1) : in_term
    dates = range(first_date; step, length=max(available, guaranteed))
    # installments due no later than the end of the mortality assumption
    covered = isinf(horizon) ? in_term : searchsortedlast(dates, horizon)
    contingent_end = isnothing(in_term) ? covered : min(in_term, covered)
    # whether life-contingent installments carry on past the end of the assumption
    continues = isnothing(in_term) || in_term > max(covered, guaranteed)
    return (; times=dates[1:max(guaranteed, contingent_end)], guaranteed, continues, horizon)
end

# Guaranteed installments are a certain payment; the rest are paid while the life is in force.
function unit_payments(ins::Annuity)
    s = schedule(ins)
    s.continues && !iszero(survival(ins.life, s.horizon)) && throw(beyond_assumption(s.horizon))
    guaranteed = s.times[1:s.guaranteed]
    contingent = s.times[s.guaranteed+1:end]
    contract = (
        guaranteed=CertainPayment(guaranteed, fill(one(probability_type(ins.life)), length(guaranteed))),
        contingent=in_force_payment(ins.life, contingent),
    )
    return (; contract, grid=from_issue(contingent), contingent)
end

# Expected unit payments, in date order, from one projection of the contract.
function expected_payments(ins::DeathBenefit)
    (; contract, grid) = unit_payments(ins)
    return [cf.amount for cf in project_from_issue(contract, ins.life, grid).cashflows.benefit]
end

function expected_payments(ins::Annuity)
    (; contract, grid, contingent) = unit_payments(ins)
    cashflows = project_from_issue(contract, ins.life, grid).cashflows
    # the contingent component is dated at every grid time, and the grid ends with its dates
    return [cf.amount for cf in [cashflows.guaranteed; last(cashflows.contingent, length(contingent))]]
end

# The probability of being in force at each of `dates` (sorted), from one projection.
function in_force_at(life, dates)
    cashflows = project_from_issue((in_force=in_force_payment(life, dates),), life, from_issue(dates)).cashflows
    return [cf.amount for cf in last(cashflows.in_force, length(dates))]
end
