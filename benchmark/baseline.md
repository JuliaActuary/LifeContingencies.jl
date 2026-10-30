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

## After the 3.0 API follow-ups

Same-machine comparison against the documentation tip `4811d11`, using Julia 1.13.1,
MortalityTables 3.0.0 and FinanceCore 3.0.1 for **both** runs:

| Workload | Documentation tip | API follow-ups | Follow-up allocation |
|---|---:|---:|---:|
| whole life PV | 4.1 μs | 3.9 μs | 816 bytes |
| annuity due PV | 8.8 μs | 8.6 μs | 2,544 bytes |
| monthly annuity, 10 years certain | 55.1 μs | 57.3 μs | 11,488 bytes |
| whole-life scalar reserves, durations 1–70 | 1,359.2 μs | 1,364.3 μs | 994,448 bytes |
| priced-policy scalar values, durations 1–70 | — | 397.0 μs | 772,688 bytes |
| priced-policy value column, durations 1–70 | — | 209.9 μs | 351,200 bytes |
| joint last-survivor annuity | 14.3 μs | 13.5 μs | 3,408 bytes |

The whole-life convenience path retains the existing backward kernel without history.
Storing the issue premium avoids repeated pricing; requesting a column additionally avoids
repeated occupancy and backward passes. The column is about 6.5× faster than the existing
convenience loop in this workload. The suite checks linear mortality-read growth when the
column horizon doubles, including the terminal zero reserve. Exact term cash-flow read
counts remain 100 and 400 for 100- and 400-period tables.

The public priced-policy API is now `PricedPolicy` / `policy_value`; the timings above
refer to the same valuation kernels. [Issue #94](https://github.com/JuliaActuary/LifeContingencies.jl/issues/94)
is addressed by the typed column implementation below.

## Typed policy-value columns (#94)

Same-machine warm comparison with Julia 1.13.1, FinanceCore 3.0.1 and MortalityTables
3.0.0, against `de823e4`. Run `julia --project=. benchmark/policy_values.jl --profile`.
The script uses identical workload definitions in each worktree, warms every call, reports
minimum bulk timings across 20 samples, and reports allocations separately from profiling.
It prints the package source path to confirm which implementation is being measured.

| Workload | Before | Typed buffers | Before allocation | Typed allocation |
|---|---:|---:|---:|---:|
| Whole-life scalar at duration 10 | 5.8 μs | 4.1 μs | 14,816 bytes | 6,944 bytes |
| Whole-life one-element column at 10 | 28.0 μs | 4.5 μs | 45,712 bytes | 6,976 bytes |
| Whole-life 76-date column | 226.0 μs | 4.9 μs | 339,872 bytes | 10,992 bytes |
| 20-pay life 76-date column | 231.8 μs | 4.9 μs | 338,848 bytes | 10,992 bytes |
| Monthly-premium endowment column | 188.9 μs | 20.9 μs | 594,800 bytes | 33,968 bytes |
| Guaranteed annuity, observed dead | 73.3 μs | 9.2 μs | 187,424 bytes | 23,104 bytes |
| Joint monthly-premium column | 302.0 μs | 51.7 μs | 881,920 bytes | 60,048 bytes |

The whole-life column is about 46× faster and allocates about 97% less. The one-element
column now costs about the same as the scalar, so both use the same kernel; the annual
whole-life scalar special case is removed. Timing ratios are observations, not CI gates.

Warm profiling isolated per-date value extraction, dictionaries, snapshot construction and
allocation in the former adapter. The new adapter separates these costs as follows:

- Mortality rows are read and validated once during the forward pass, then cached in typed
  two- or four-state tuples for backward reuse. Annual grids stay integer ranges, avoiding
  unnecessary sorting and fractional-age survival calculations.
- Reachability is a byte mask per date. Later observations seed their own states, including
  states with zero issue probability; unneeded rows beyond mortality support are not read.
- Discounting and contract state/transition amounts remain in the backward recurrence.
  Certain-payment suffixes retain their stable interval-factor sweep.
- Result storage holds typed query distributions and rolling state values, with no Dict
  distributions or Vector{Any} value histories. Conditioning uses immutable tuple bindings
  so normalization does not introduce boxed numeric temporaries.

The suite checks scalar/column equality, independent prospective oracles, both joint
contingencies and payment phases, late guarantees, invalid rows, BigFloat output, inference,
linear mortality-read growth, and a loose allocation ceiling that detects per-date dictionary
regressions. There are no absolute wall-clock test thresholds.
