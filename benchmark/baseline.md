# Benchmark baseline

Recorded on branch `refactor/01-baseline-mt3` (PR 1), after the MortalityTables 3 migration and before any algorithm changes. PR 4 sets its budgets from these numbers. The baseline uses MortalityTables 3 rather than `master`'s 2.6, so that later comparisons share a dependency set.

Reproduce with `julia --project=. benchmark/baseline.jl`. Times are the minimum of 20 runs after a warm-up. Compare them only against runs on the same machine. Mortality-read counts are exact and machine-independent.

Apple M4 Max, Julia 1.13.1, MortalityTables 3.0.0, FinanceCore 2.8.0:

| Workload | Min time | Allocated |
|---|---:|---:|
| whole life PV (2001 VBT select, age 30) | 2.0 μs | 64 bytes |
| annuity due PV (2001 VBT select, age 30) | 3.7 μs | 80 bytes |
| net premium reserves, durations 1–70 | 627.4 μs | 2,224 bytes |
| joint last-survivor annuity due PV (CIA) | 17.6 μs | 27,360 bytes |
| 100-year term cash flows, 100-period table | 3.5 μs | 928 bytes |
| 400-year term cash flows, 400-period table | 42.9 μs | 3,648 bytes |

| Mortality reads for term cash flows | Count |
|---|---:|
| 100-period table | 5,050 |
| 400-period table | 80,200 |

The read counts are n(n+1)/2: every payment recomputes survival from issue. PR 4's target is linear growth.

The synthetic workloads were first recorded as whole-life insurance on rates that never reach 1. The PR 1 code truncated that at the end of the table, which is the same computation as the n-year terms the script now uses. Since PR 4, whole life on such rates raises a `DomainError`.
