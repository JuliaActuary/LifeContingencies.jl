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

Same machine and versions. Both columns come from the current script, which times short workloads in bulk, so the PR 1 column reruns it against PR 1's code and differs a little from the table above.

| Workload | PR 1 | PR 4 | Ratio | PR 1 allocated | PR 4 allocated |
|---|---:|---:|---:|---:|---:|
| whole life PV (2001 VBT select, age 30) | 2.2 μs | 3.0 μs | 1.4× | 64 bytes | 816 bytes |
| annuity due PV (2001 VBT select, age 30) | 2.2 μs | 4.7 μs | 2.1× | 80 bytes | 2,544 bytes |
| monthly annuity due PV, 10 years certain | 24.7 μs | 41.9 μs | 1.7× | 96 bytes | 11,488 bytes |
| net premium reserves, durations 1–70 | 641.4 μs | 836.9 μs | 1.3× | 2,224 bytes | 998,928 bytes |
| joint last-survivor annuity due PV (CIA) | 18.9 μs | 12.3 μs | 0.65× | 27,360 bytes | 3,408 bytes |
| 100-year term cash flows, 100-period table | 2.0 μs | 3.1 μs | 1.6× | 928 bytes | 6,640 bytes |
| 400-year term cash flows, 400-period table | 43.2 μs | 11.1 μs | 0.26× | 3,648 bytes | 23,088 bytes |
| mortality reads, 100-year term | 5,050 | 100 | | | |
| mortality reads, 400-year term | 80,200 | 400 | | | |

The test suite enforces the structural properties: mortality reads grow linearly with the projection length, a scalar present value allocates the same however long its contract runs, and the engine's time grows linearly with the states each step touches.

Budgets, all met. They were set after measuring a first version of PR 4, not before it.
- Mortality reads grow linearly with the projection length.
- Long projections (400 periods) take at most half their PR 1 time.
- Joint products are no slower than in PR 1.
- Single-contract textbook values stay within 2.5× of PR 1; the slowest is 2.1×.

Where the time goes:
- **Bookkeeping.** Each projection step costs about 20 ns of occupancy bookkeeping on top of the mortality rows, which PR 1's closed-form survival products didn't pay.
- **Annuity grids.** Annuities step over a floating-point grid, which makes each row's fractional-age survival dearer than on the death benefit's integer grid.
- **Allocation.** A scalar value allocates under a kilobyte for its buffers, independent of the contract length. An annuity whose first life-contingent payment comes after issue, because of a guarantee, a deferral or payment in arrears, also builds its grid of dates as a vector; that is most of the monthly annuity's 11 KB.
- **Reserves.** Each reserve runs four linear passes: two for the issue premium, one for the in-force distribution at `t`, and the backward valuation.
