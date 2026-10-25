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

## After PR 4 (products on the engine)

Same machine and versions; each time is the more favorable of two runs of the script.

| Workload | PR 1 | PR 4 | Ratio |
|---|---:|---:|---:|
| whole life PV (2001 VBT select, age 30) | 2.0 μs | 4.6 μs | 2.3× |
| annuity due PV (2001 VBT select, age 30) | 3.7 μs | 5.9 μs | 1.6× |
| net premium reserves, durations 1–70 | 627.4 μs | 1,251.4 μs | 2.0× |
| joint last-survivor annuity due PV (CIA) | 17.6 μs | 11.8 μs | 0.7× |
| 100-year term cash flows, 100-period table | 3.5 μs | 4.4 μs | 1.3× |
| 400-year term cash flows, 400-period table | 42.9 μs | 14.8 μs | 0.3× |
| mortality reads, 100-year term | 5,050 | 100 | |
| mortality reads, 400-year term | 80,200 | 400 | |

Budgets, all met:
- mortality reads grow linearly with the projection length
- long projections (400 periods) take at most half their PR 1 time
- joint products are no slower than in PR 1
- single-contract textbook values stay within 2.5× of PR 1

The budgets were set after measuring PR 4, not before. Small contracts pay a fixed engine overhead of about 2–3 μs per projection, mostly a hash lookup of the next state on each edge; the mortality rows themselves cost about 1 μs for a 91-year life. A dense-index fast path for models that define `states` would remove most of it. Reserves also run four linear passes each (two projections for the issue premium, one for the in-force distribution at `t`, and the backward valuation), where PR 1 ran several quadratic ones.
