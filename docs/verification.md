# Verification methodology and test-suite status

How every result in this project is checked, and the current state of the
regression suite.  Back to the [README](../README.md).

## Methodology

Correctness is the project's first-class concern. Every test's SystemVerilog is
synthesized and then **independently verified** by one or more of:

1. **Formal equivalence (`equiv_induct`)** — the UHDM-frontend netlist is proven
   sequentially equivalent to the netlist produced by Yosys's own Verilog frontend
   (the golden reference), using `equiv_make` / `equiv_simple` / `equiv_induct`.
2. **Sound SAT-from-reset miter** — a bounded model-check from the reset state
   (`miter` + `sat -prove-asserts -seq N -set-init-zero`) that is **sound**: it
   never false-passes. It is the adjudicator of record — when `equiv_induct` can't
   close an inductive proof, the miter decides whether the two netlists are truly
   equivalent (an induction gap, *not* a bug) or genuinely divergent (a real bug).
3. **High-activity randomized Verilator co-simulation** — the UHDM-synthesized
   gate-level netlist is co-simulated against the original RTL under randomized,
   high-toggle-activity stimulus (all clocks driven, reset wiggled, activity
   guards) to catch functional divergences a vacuous stimulus would miss.

A result is only counted as **Correct** when formal equivalence and/or co-simulation
proves it; designs the native Verilog frontend cannot even parse ("SV-only") are
verified against the RTL by co-simulation, since there is no golden netlist to
compare against. This asymmetric, miter-adjudicated policy is why the tables here
report **0 Miter-Formal escapes** — no real UHDM≠Verilog difference slips through.

## Test suite status

`make test-all --all` runs the internal SystemVerilog suite plus the upstream
Yosys suite -- the same run as the sharded
[Regression](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/regression-sharded.yml)
workflow (every PR + nightly); the developer run is
`cd test && ./run_parallel.sh 6 --no-cva6` (the internal tests, ~24 min), and
a PR lands only on a clean run.  The counts are the regression's own summary
of main at `5d97aff5a` (2026-10-25, run 40195316215), not a tally kept by
hand; "upstream" is the 515 generated yosys tests the suite scores.  The 11
upstream failures are the Yosys 0.70 bump's, each recorded in
`test/failing_tests.txt`.

| | Total | Internal SV | Upstream Yosys |
|---|---|---|---|
| Tests | 1879 | 1364 | 515 |
| Functional | 1832 (97%) | 1328 | 504 |
| True failures | 11 | **0** | 11 |
| Crashes | **0** | **0** | **0** |

- **0 Miter-Formal escapes** — no UHDM≠Verilog difference slips past
  `equiv_induct`.  This is the number that matters: every equivalence failure
  is one `equiv_induct` caught.
- **1100** tests formally equivalent UHDM vs Verilog; **732** UHDM-only
  (constructs `read_verilog` cannot parse) verified against Verilator;
  **350 / 351** SV-only designs also proven against `read_slang` (1 known-fail,
  tracked in `test/slang_miter_expected_fail.txt`), and **96**
  carry a `test_structural.ys` netlist-SHAPE gate for defects no formal check
  can see (a dropped flop, a missing `$mem` or a dropped clock connection still
  "works" — it just returns constants).
- **16 equivalence failures**, each with a recorded verdict in
  `test/failing_tests.txt`.  In several the *reference* is the wrong side
  (`read_verilog` mis-lowers the construct) — a SAT miter against `read_slang`
  proves UHDM correct.
- **Sim-equiv ratchet** (`test/sim_equiv_warn_baseline.txt`, shrink-only): 85
  divergences outstanding across the full corpus, 0 new; 75 of them analyzed,
  57 shown by a miter to be sim/synth artefacts and 18 still unclassified
  (miter inconclusive).