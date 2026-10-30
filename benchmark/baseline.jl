# Baseline workloads for the refactor's performance budgets (see REFACTOR_PLAN.md, PR 4).
# Run from the repository root:  julia --project=. benchmark/baseline.jl
#
# Mortality reads are exact counts. Times are the minimum over `SAMPLES` samples after a
# warm-up run, each sample repeating the workload for about `SAMPLE_SECONDS` so that short
# workloads are timed in bulk. Compare them only against results from the same machine.

using LifeContingencies, MortalityTables, FinanceCore
using Printf

const SAMPLES = 20
const SAMPLE_SECONDS = 0.01

struct CountingMortality <: AbstractVector{Float64}
    q::Vector{Float64}
    reads::Base.RefValue{Int}
end
Base.size(m::CountingMortality) = size(m.q)
Base.IndexStyle(::Type{CountingMortality}) = IndexLinear()
Base.getindex(m::CountingMortality, i::Int) = (m.reads[] += 1; m.q[i])

function measure(f)
    f()
    repeats = max(1, round(Int, SAMPLE_SECONDS / @elapsed(f())))
    seconds = minimum(@elapsed(for _ in 1:repeats; f(); end) for _ in 1:SAMPLES) / repeats
    bytes = @allocated f()
    return seconds, bytes
end

function report(name, f)
    seconds, bytes = measure(f)
    @printf("%-44s %12.1f μs %12d bytes\n", name, 1e6 * seconds, bytes)
end

function mortality_reads(n)
    m = CountingMortality(fill(0.01, n), Ref(0))
    collect(cashflows(Insurance(SingleLife(m), 0.0, n)))
    return m.reads[]
end

vbt = MortalityTables.table("2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB")
lc = LifeContingency(SingleLife(vbt.select[30], issue_age=30), 0.05)

cia_male = MortalityTables.table("1986-92 CIA – Male Smoker, ANB")
cia_female = MortalityTables.table("1986-92 CIA – Female Nonsmoker, ANB")
joint = JointLife(lives=(SingleLife(cia_male.ultimate, issue_age=40), SingleLife(cia_female.ultimate, issue_age=37)))

println("Julia ", VERSION, ", MortalityTables ", pkgversion(MortalityTables), ", FinanceCore ", pkgversion(FinanceCore))
println()
@printf("%-44s %15s %18s\n", "workload", "min time", "allocated")
report("whole life PV (2001 VBT select, age 30)", () -> present_value(Insurance(lc)))
report("annuity due PV (2001 VBT select, age 30)", () -> present_value(AnnuityDue(lc)))
report("monthly annuity due PV, 10 years certain", () -> present_value(AnnuityDue(lc; certain=10, frequency=12)))
report("net premium reserves, durations 1-70", () -> sum(t -> reserve_premium_net(lc, t), 1:70))
report("joint last-survivor annuity due PV (CIA)", () -> present_value(AnnuityDue(joint, 0.05)))
for n in (100, 400)
    m = UltimateMortality(fill(0.01, n))
    report("$n-year term cash flows, $n-period table", () -> collect(cashflows(Insurance(SingleLife(m), 0.0, n))))
end
println()
for n in (100, 400)
    @printf("%-44s %15d\n", "mortality reads, $n-year term", mortality_reads(n))
end
