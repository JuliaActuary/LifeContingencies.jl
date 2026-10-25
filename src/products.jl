##################
### Insurances ###
##################

abstract type Insurance end

function LifeContingency(ins::I) where {I<:Insurance}
    LifeContingency(ins.life, ins.int)
end

## The products are valued by projecting unit payments through the experimental engine,
## from each life's status at issue.

project_from_issue(contract, life, grid) =
    project(contract, life; grid, initial=initial_distribution(life), numbertype=probability_type(life))

probability_type(life) = typeof(last(only(initial_distribution(life))))

death_payment(life) = TransitionPayment((interval, from, to) -> active(life, from) && !active(life, to) ? 1 : 0)
in_force_payment(life) = StatePayment((t, state) -> active(life, state) ? 1 : 0)

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

Issue age is based on the `issue_age` in the LifeContingency `lc`.

# Examples

```
ins = Insurance(
    SingleLife(mortality = UltimateMortality([0.5,0.5]),issue_age = 0),
    FinanceModels.Yield.Constant(0.05),
    1           # 1 year term
)
```
"""
Insurance(life, int, term=nothing) = DeathBenefit(life, int, checked_term(term))
Insurance(lc::LifeContingency, args...) = Insurance(lc.life, lc.int, args...)

# The years a death benefit runs: its term, ending early at the last whole year the mortality
# assumption covers.
function benefit_years(ins::DeathBenefit)
    horizon = omega(ins.life)
    isnothing(ins.term) && isinf(horizon) &&
        throw(DomainError(horizon, "parametric mortality never reaches extinction, so a whole-life insurance needs a `term`"))
    covered = isinf(horizon) ? ins.term : floor(Int, horizon)
    return isnothing(ins.term) ? covered : min(ins.term, covered)
end

# One projection from issue gives every view of a death benefit.
function expected_payments(ins::DeathBenefit)
    years = benefit_years(ins)
    p = project_from_issue((death=death_payment(ins.life), in_force=in_force_payment(ins.life)), ins.life, 0:years)
    in_force = [cf.amount for cf in p.cashflows.in_force]
    continues = isnothing(ins.term) || ins.term > years
    continues && !iszero(last(in_force)) && throw(beyond_assumption(omega(ins.life)))
    return (probability=[cf.amount for cf in p.cashflows.death], survival=in_force[1:end-1])
end

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

```
ins = AnnuityDue(
    SingleLife(mortality = UltimateMortality([0.5,0.5]),issue_age = 0),
    FinanceModels.Yield.Constant(0.05),
    1, # term of policy
) 
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

```
ins = AnnuityImmediate(
    SingleLife(mortality = UltimateMortality([0.5,0.5]),issue_age = 0),
    FinanceModels.Yield.Constant(0.05),
    1 # term of policy
) 
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

# The probability of being in force at each of `times` (increasing), from one projection.
function in_force_at(life, times)
    isempty(times) && return probability_type(life)[]
    grid = unique!([0.0; times])
    p = project_from_issue((in_force=in_force_payment(life),), life, grid)
    in_force = Dict(cf.time => cf.amount for cf in p.cashflows.in_force)
    return [in_force[t] for t in times]
end

# Guaranteed installments are paid for certain; the rest only while the life is in force.
function expected_payments(ins::Annuity)
    s = schedule(ins)
    contingent = s.times[s.guaranteed+1:end]
    checked = s.continues ? [contingent; s.horizon] : collect(contingent)
    in_force = in_force_at(ins.life, checked)
    s.continues && !iszero(last(in_force)) && throw(beyond_assumption(s.horizon))
    return [ones(probability_type(ins.life), s.guaranteed); in_force[1:length(contingent)]]
end
