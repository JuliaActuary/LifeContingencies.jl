##################
### Insurances ###
##################

abstract type Insurance end

function LifeContingency(ins::I) where {I<:Insurance}
    LifeContingency(ins.life, ins.int)
end

struct WholeLife{L,Y} <: Insurance
    life::L
    int::Y
end

struct Term{L,Y} <: Insurance
    life::L
    int::Y
    term::Int
end

"""
    Insurance(lc::LifeContingency, term)
    Insurance(life,interest, term)
    Insurance(lc::LifeContingency)
    Insurance(life,interest)

Life insurance with a term period of `term`. If `term` is `nothing`, then whole life insurance.

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
Insurance(lc::LifeContingency, term) = Insurance(lc.life, lc.int, term)
Insurance(lc::LifeContingency) = Insurance(lc.life, lc.int)

function Insurance(life, int, term::Int)
    term < 1 && return ZeroBenefit(life, int)
    return Term(life, int, term)
end
function Insurance(life, int)
    return WholeLife(life, int)
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
