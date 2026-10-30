# Run with --profile to sample a warmed column; run against both worktree environments
# for a same-machine comparison. The baseline supplies warmed bulk timing/allocation helpers.
include("baseline.jl")
using Profile
println("\nPolicy-value workload matrix (source: ", pathof(LifeContingencies), ")")
basis = LifeContingency(SingleLife(vbt.select[45]), 0.04)
whole = PricedPolicy(Insurance(basis), AnnuityDue(basis))
report("whole life scalar at 10", () -> policy_value(whole, 10))
report("whole life one-element column at 10", () -> policy_value(whole, [10]))
report("whole life 76-date column", () -> policy_value(whole, 0:75))
limited = PricedPolicy(Insurance(basis), AnnuityDue(basis, 20))
report("20-pay life 76-date column", () -> policy_value(limited, 0:75))
monthly = PricedPolicy(Endowment(basis, 20), AnnuityDue(basis, 20; frequency=12))
report("monthly-premium endowment column", () -> policy_value(monthly, 0:20))
guaranteed = PricedPolicy(AnnuityDue(basis, 20; certain=10, frequency=12), AnnuityDue(basis, 1))
report("guaranteed annuity, observed dead", () -> policy_value(guaranteed, 1:20; state=:dead))
jbasis = LifeContingency(joint, 0.04)
jpolicy = PricedPolicy(Endowment(jbasis, 20), AnnuityDue(jbasis, 20; frequency=12))
report("joint monthly-premium column", () -> policy_value(jpolicy, 0:20))

if "--profile" in ARGS
    policy_value(whole, 0:75)
    Profile.clear()
    @profile for _ in 1:50_000
        policy_value(whole, 0:75)
    end
    Profile.print(; format=:flat, sortedby=:count, mincount=10)
end
