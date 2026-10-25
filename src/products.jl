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
    "the contract continues past the end of the mortality rates at time $t while lives remain in force; supply rates that reach extinction (a rate of 1), or give the contract a shorter term")

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

# The years a death benefit runs: its term, ending early when the mortality assumption does.
function benefit_years(ins::DeathBenefit)
    horizon = omega(ins.life)
    isnothing(ins.term) && isinf(horizon) &&
        throw(DomainError(horizon, "parametric mortality never reaches extinction, so a whole-life insurance needs a `term`"))
    return Int(isnothing(ins.term) ? horizon : min(ins.term, horizon))
end

# One projection from issue gives every view of a death benefit.
function expected_payments(ins::DeathBenefit)
    years = benefit_years(ins)
    p = project_from_issue((death=death_payment(ins.life), in_force=in_force_payment(ins.life)), ins.life, 0:years)
    in_force = [cf.amount for cf in p.cashflows.in_force]
    continues = isnothing(ins.term) || ins.term > years
    continues && !iszero(last(in_force)) && throw(beyond_assumption(years))
    return (probability=[cf.amount for cf in p.cashflows.death], survival=in_force[1:end-1])
end

abstract type AnnuityKind end
struct Due <: AnnuityKind end
struct Immediate <: AnnuityKind end

abstract type AnnuityPayable end
abstract type AnnuityCertain <: AnnuityPayable end

struct TermCertain <: AnnuityCertain
    term::Int
    certain::Int
end
struct LifeCertain <: AnnuityCertain
    certain::Int
end
struct TermAnnuity <: AnnuityPayable
    term::Int
end
struct LifeAnnuity <: AnnuityPayable end

struct Annuity{L,Y,K<:AnnuityKind,P<:AnnuityPayable} <: Insurance
    life::L
    int::Y
    kind::K
    payable::P
    start_time::Int
    frequency::Int
end
struct ZeroBenefit{L,Y} <: Insurance
    life::L
    int::Y
end

function ZeroBenefit(lc::LifeContingency)
    return ZeroBenefit(lc.life, lc.int)
end

"""
    AnnuityDue(lc::LifeContingency; n=nothing, start_time=0; certain=nothing,frequency=1)
    AnnuityDue(life, interest; n=nothing, start_time=0; certain=nothing,frequency=1)

Annuity due with the benefit period starting at `start_time` and ending after `n` periods with `frequency` payments per year of `1/frequency` amount and a `certain` period with non-contingent payments. 

# Examples

```
ins = AnnuityDue(
    SingleLife(mortality = UltimateMortality([0.5,0.5]),issue_age = 0),
    FinanceModels.Yield.Constant(0.05),
    1, # term of policy
) 
```
"""
function AnnuityDue(life, int, term; certain=nothing, start_time=0, frequency=1)
    term < 1 && return ZeroBenefit(life, int)
    if isnothing(certain)
        Annuity(life, int, Due(), TermAnnuity(term), start_time, frequency)
    else
        Annuity(life, int, Due(), TermCertain(term, certain), start_time, frequency)
    end
end

function AnnuityDue(life, int; certain=nothing, start_time=0, frequency=1)
    if isnothing(certain)
        Annuity(life, int, Due(), LifeAnnuity(), start_time, frequency)
    else
        Annuity(life, int, Due(), LifeCertain(certain), start_time, frequency)
    end
end

function AnnuityDue(lc::L, term; certain=nothing, start_time=0, frequency=1) where {L<:LifeContingency}
    return AnnuityDue(lc.life, lc.int, term; certain, start_time, frequency)
end

function AnnuityDue(lc::L; certain=nothing, start_time=0, frequency=1) where {L<:LifeContingency}
    return AnnuityDue(lc.life, lc.int; certain, start_time, frequency)
end

"""
    AnnuityImmediate(lc::LifeContingency; term=nothing, start_time=0; certain=nothing,frequency=1)
    AnnuityImmediate(life, interest; term=nothing, start_time=0; certain=nothing,frequency=1)

Annuity immediate with the benefit period starting at `start_time` and ending after `term` periods with `frequency` payments per year of `1/frequency` amount and a `certain` period with non-contingent payments. 

# Examples

```
ins = AnnuityImmediate(
    SingleLife(mortality = UltimateMortality([0.5,0.5]),issue_age = 0),
    FinanceModels.Yield.Constant(0.05),
    1 # term of policy
) 
```

"""
function AnnuityImmediate(life, int, term; certain=nothing, start_time=0, frequency=1)
    term < 1 && return ZeroBenefit(life, int)
    if isnothing(certain)
        Annuity(life, int, Immediate(), TermAnnuity(term), start_time, frequency)
    else
        Annuity(life, int, Immediate(), TermCertain(term, certain), start_time, frequency)
    end
end

function AnnuityImmediate(life, int; certain=nothing, start_time=0, frequency=1)
    if isnothing(certain)
        Annuity(life, int, Immediate(), LifeAnnuity(), start_time, frequency)
    else
        Annuity(life, int, Immediate(), LifeCertain(certain), start_time, frequency)
    end
end

function AnnuityImmediate(lc::L, term; certain=nothing, start_time=0, frequency=1) where {L<:LifeContingency}
    return AnnuityImmediate(lc.life, lc.int, term; certain, start_time, frequency)
end

function AnnuityImmediate(lc::L; certain=nothing, start_time=0, frequency=1) where {L<:LifeContingency}
    return AnnuityImmediate(lc.life, lc.int; certain, start_time, frequency)
end
