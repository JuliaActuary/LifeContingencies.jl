# An academic long-term care model for `LifeContingencies.Experimental`.
#
# Monthly steps. A policyholder is healthy, on claim, dead or lapsed, and each state also
# carries the contract's memory: how long the current claim has lasted, whether the
# elimination period has been satisfied, and how many benefit months have been paid.
# The rates are illustrative, not from any experience study. docs/src/ltc.md gives the
# specification and its simplifications.

using LifeContingencies.Experimental

struct LTCState
    status::Symbol         # :healthy, :claim, :dead or :lapsed
    claim_months::Int      # whole months in the current claim, counted up to `claim_months_counted`
    qualified::Bool        # whether the elimination period has been satisfied (once per lifetime)
    benefit_months::Int    # benefit months paid so far, across all claims
end

const HEALTHY = LTCState(:healthy, 0, false, 0)
const DEAD = LTCState(:dead, 0, false, 0)
const LAPSED = LTCState(:lapsed, 0, false, 0)

# claim termination rates change after this many months on claim
const RATE_BANDS = 6

Base.@kwdef struct LTCModel
    issue_age::Int = 75
    elimination_months::Int = 3
    maximum_benefit_months::Int = 24
    # annual forces, by completed years since issue
    healthy_mortality::Float64 = 0.03     # at issue, growing by `mortality_growth` a year
    mortality_growth::Float64 = 0.09
    incidence::Float64 = 0.02             # at issue, growing by `incidence_growth` a year
    incidence_growth::Float64 = 0.10
    lapse::Float64 = 0.03
    # annual forces on claim, for the first `RATE_BANDS` months and after
    recovery::NTuple{2,Float64} = (0.6, 0.2)
    claim_mortality::NTuple{2,Float64} = (0.25, 0.15)
end

const MONTH = 1 / 12
months(years) = range(0, years, length=12years + 1)

# Probabilities of staying and of each exit over a step of length h, under constant forces.
function exits(forces, h)
    total = sum(forces)
    stay = exp(-total * h)
    return stay, map(μ -> iszero(total) ? zero(μ) : μ / total * (1 - stay), forces)
end

care_payable(m::LTCModel, s::LTCState) =
    s.status === :claim && s.qualified && s.benefit_months < m.maximum_benefit_months

# Claim duration matters until both the rate band and the elimination period are settled,
# so it is counted that far and no further, which keeps the states few.
claim_months_counted(m::LTCModel) = max(RATE_BANDS, m.elimination_months)

# A claim that has lasted `months` whole months. It qualifies once it has lasted the
# elimination period, so with no elimination period it qualifies as it starts.
on_claim(m::LTCModel, months, qualified, benefit_months) =
    LTCState(:claim, min(months, claim_months_counted(m)), qualified || months >= m.elimination_months, benefit_months)

# Every row has four entries so that all rows have one type.
function LifeContingencies.Experimental.transitions(m::LTCModel, interval::Interval, s::LTCState)
    isapprox(interval.stop - interval.start, MONTH) ||
        throw(ArgumentError("the LTC model moves in steps of one month; got $interval"))
    years = round(Int, 12 * interval.start) ÷ 12
    if s.status === :healthy
        forces = (m.incidence * exp(m.incidence_growth * years), m.healthy_mortality * exp(m.mortality_growth * years), m.lapse)
        stay, (incidence, death, lapse) = exits(forces, MONTH)
        claim = on_claim(m, 0, s.qualified, s.benefit_months)
        return (s => stay, claim => incidence, DEAD => death, LAPSED => lapse)
    elseif s.status === :claim
        band = s.claim_months < RATE_BANDS ? 1 : 2
        stay, (recovery, death) = exits((m.recovery[band], m.claim_mortality[band]), MONTH)
        continuing = on_claim(m, s.claim_months + 1, s.qualified, s.benefit_months + care_payable(m, s))
        recovered = LTCState(:healthy, 0, s.qualified, s.benefit_months)
        return (continuing => stay, recovered => recovery, DEAD => death, DEAD => 0.0)
    else
        return (s => 1.0, s => 0.0, s => 0.0, s => 0.0)
    end
end

# A month on claim is paid in full. A month that ends in recovery or death is paid for half,
# and doesn't count toward the maximum.
function care_payment(m::LTCModel, from::LTCState, to::LTCState)
    care_payable(m, from) || return 0.0
    to.status === :claim && return 1.0
    to.status in (:healthy, :dead) && return 0.5
    return 0.0
end

# A `term`-year policy: a monthly premium at the start of each month while healthy (waived on
# claim), a monthly care benefit, and a benefit on death. Nothing is paid for a month that
# ends after the term, however far the projection grid runs.
function ltc_contract(m::LTCModel; term, premium, care=1.0, death=1.0)
    return (
        premium=StatePayment((t, s) -> s.status === :healthy && t < term ? -premium : 0.0),
        care=TransitionPayment((interval, from, to) -> interval.stop <= term ? care * care_payment(m, from, to) : 0.0),
        death=TransitionPayment((interval, from, to) ->
            interval.stop <= term && from.status in (:healthy, :claim) && to.status === :dead ? death : 0.0),
    )
end
