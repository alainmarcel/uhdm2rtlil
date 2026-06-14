---
name: verify-uhdm-equivalence
description: Verify a UHDM-frontend test or fix is correct — runs the full pipeline (frontend workflow → thorough Verilator co-sim → formal equiv_induct → sound SAT-from-reset miter) and interprets the trichotomy verdict (real bug vs artefact vs inconclusive). Use after changing src/frontends/uhdm/ or adding/triaging a test, and whenever asked to "check equivalence", "make sure the cosim passes", or decide whether a divergence is a real frontend bug.
---

# Verifying UHDM → RTLIL equivalence

The UHDM frontend converts SystemVerilog→RTLIL. "Is the output correct?" is
answered by comparing it against Yosys's own Verilog frontend and against the
behavioural RTL, with four complementary, **all checked-in** tools under
`test/`. No tool is sufficient alone — each has a blind spot the next covers.

Run everything from `test/`. Tests live in `test/<name>/` with a `dut.sv`.

## The pipeline (run in this order)

### 1. Frontend workflow — `./test_uhdm_workflow.sh <name>`
Surelog parses `dut.sv`→UHDM; reads it through the UHDM frontend AND through
Yosys's Verilog frontend; writes `<name>_from_uhdm{,_nohier}.il`,
`<name>_from_verilog{,_nohier}.il`, and post-`synth` `*_synth.v` for both;
compares gate counts and RTLIL. **This regenerates the `*_synth.v` that tools
3 and 4 consume — always run it first after a frontend change.** A pre-synth
RTLIL diff is normal and expected (different but equivalent structure); gate
counts that match are a good sign, a difference is only a hint.

### 2. Thorough co-sim — `python3 test_sim_equivalence.py <name>`
Verilator runs the UHDM-frontend's synthesized netlist side-by-side with the
behavioural `dut.sv`, shared clocks/resets, randomized inputs, cycle-by-cycle
output compare. Prints `PASS`/`FAIL` and an `ACTIVITY:` line.
- **Stimulus is deliberately thorough**: toggles ALL clocks, *wiggles*
  resets/enables mid-run (not pinned de-asserted), and guards against a vacuous
  pass with an output-activity check. A `VACUOUS` warning or `bits_ever_set`
  near zero means the outputs never moved — the PASS proves nothing; fix the
  testbench/DUT controllability before trusting it.
- A bare `PASS` with high activity is strong but NOT sound on its own (it is
  bounded random simulation). Confirm with tool 3 or 4.

### 3. Formal equiv — `./test_equivalence.sh <name>`
`equiv_make` + `equiv_induct` between UHDM and Verilog netlists.
- **Blind spot — unsound induction**: `equiv_induct` silently PASSES some
  non-equivalent designs (unreachable-state invariants it can't refute). A PASS
  here is suggestive, **never proof**.
  - ⛔ **NEVER declare equivalence — and NEVER call a remaining co-sim
    divergence an "artefact"/"div-by-zero x"/"optimization" — on the strength of
    an `equiv_induct` PASS.** That is the single easiest way to ship a real bug.
    You MUST clear it with the sound miter (tool 4) first. Observed failure
    mode: after a partial fix, `equiv_induct` PASSED the `operators` test while
    the sound miter still found a NON-EQUIVALENT counterexample — a second real
    sign/width bug `equiv_induct` masked. If the miter is INCONCLUSIVE (e.g. an
    unmodellable `$pow`/`$div`), REMOVE/ISOLATE the unmodellable operator and
    re-run the miter on the rest — do not fall back to the equiv_induct PASS.
- **Blind spot — async FFs / public gate types**: on Yosys 0.64 it can abort
  with "No SAT model available for cell …". That is a flow limitation, not a
  frontend bug — fall through to tool 4 (the miter handles it).

### 4. Sound triage — `python3 triage_cosim.py <name> [--seq N] [--cycles N]`
The discriminator. Runs TWO independent sound-ish checks and prints a verdict:
- ⚠️ **The miter says they DIFFER, not which side is wrong.** Yosys's own
  Verilog frontend has bugs too, so a NON-EQUIVALENT can be the *Verilog*
  frontend being wrong while UHDM is correct. Before "fixing" UHDM to match
  Verilog, adjudicate the disputed vector with an INDEPENDENT reference
  simulator — `iverilog -g2012` (or Verilator) on the behavioural source.
  Observed: `operators` mode `s1>>s2` — miter UHDM=0xff vs Verilog=0x00;
  iverilog said 0x00, so UHDM was the buggy one — but the same run also had
  cases where iverilog matched UHDM, i.e. Verilog was wrong. Quick recipe:
  `iverilog` the behavioural DUT over all case selectors with fixed inputs,
  `yosys ... eval -set <in> <val> -show <out>` the UHDM netlist for the same
  vectors, and diff per selector — the modes where UHDM ≠ iverilog are the real
  UHDM bugs; modes where Verilog ≠ iverilog are Verilog-frontend bugs to leave
  alone. **Watch for `$pow`/`$div` etc. that satgen can't model — isolate or
  drop them so the miter can run on the rest (see the equiv_induct warning).**
- **SAT-from-reset miter** (UHDM-synth vs Verilog-synth): bounded, sound. Reads
  both `*_synth.v` with `read_verilog -icells` so write_verilog's public-typed
  built-in cells (`\$_DFFE_PN0P_`, `\$_MUX_`, …) come back as INTERNAL cells,
  then `async2sync` per design so satgen can model async resets. A counterexample
  ⇒ the UHDM netlist genuinely differs from Verilog ⇒ **real bug** (and
  equiv_induct missed it). A bounded proof ⇒ equivalent.
- **Asymmetric Verilator co-sim**: UHDM-vs-RTL and Verilog-vs-RTL. If UHDM
  fails where Verilog passes ⇒ bug; if both fail ⇒ a Verilator-vs-synth
  artefact (both frontends agree).

Verdict it prints:
- `🐛 REAL BUG` — miter NON-EQUIVALENT, or UHDM co-sim FAIL while Verilog PASS.
- `🔬 ARTEFACT` — miter EQUIVALENT (UHDM == Verilog); any co-sim diff is
  Verilator-vs-synth noise, not a frontend bug.
- `✅ CO-SIM OK` — miter INCONCLUSIVE (SAT impractical here) but BOTH co-sims
  pass: UHDM matches the reference exactly as well as Verilog does.
- `❓ INCONCLUSIVE` — investigate manually.

## Decision rule

A co-sim divergence is **only** a real frontend bug if it ALSO fails the sound
check: miter NON-EQUIVALENT, or (UHDM co-sim FAIL **and** Verilog co-sim PASS).
A vacuous co-sim PASS and an `equiv_induct` PASS each prove nothing on their own.

The symmetric trap: declaring "equivalent / the rest is an artefact" is a
positive claim that ALSO requires the sound miter. `equiv_induct` PASS + gate
counts matching is NOT sufficient — only a miter EQUIVALENT (bounded proof, on a
design with all operators modellable) lets you call remaining co-sim diffs
artefacts. When in doubt, run the miter; if it can't run, say "unverified", not
"artefact".

## Gotchas

- **Stale `*_synth.v`**: tools 3 and 4 reuse the synth netlists; only the
  workflow (tool 1) and the co-sim regenerate. After ANY frontend change,
  re-run `./test_uhdm_workflow.sh <name>` before trusting a miter/equiv verdict,
  or you will see a stale result.
- **SAT impractical**: wide multipliers, wide accumulators, and large RAMs make
  the miter's UNSAT proof hang (finding a counterexample stays fast). Lower
  `--seq` (a shallow bounded proof from reset is often enough — e.g. `--seq 4`
  proved the 16×64 FIFO in issue #326), or rely on the thorough co-sim. Don't
  wait on a hung `sat`.
- **Async FFs**: handled by tool 4's `-icells` + `async2sync`. If you write a
  one-off miter, do the same or satgen will report "No SAT model available".

## Typical end-to-end check for a fix

```bash
cd test
./test_uhdm_workflow.sh <name>          # regenerate IL + synth.v, gate counts
python3 test_sim_equivalence.py <name>  # thorough co-sim (watch ACTIVITY)
./test_equivalence.sh <name>            # formal equiv_induct (may abort on async FF)
python3 triage_cosim.py <name> --seq 8  # sound verdict
```

Then guard against regressions across the whole suite:
```bash
./run_all_tests.sh            # 297 internal tests (formal equiv each)
./run_all_tests.sh --yosys    # 523 upstream-yosys tests
```
Internal must end with 0 equivalence failures / 0 crashes; the yosys run should
not add unexpected failures beyond the pre-existing baseline in
`test/failing_tests.txt`.

## Recording the outcome — ALWAYS mark a triaged divergence

A co-sim WARNING you have triaged must NOT be left as a bare warning — record it
in the right `test/*.txt` so the suite reports it under ANALYZED (not WARNING)
and future runs don't re-triage it from scratch. Pick the file by outcome:

- **Artefact (miter EQUIVALENT, UHDM == Verilog)** → add a `Test: <basename>`
  entry to **`test/sim_equiv_analyzed.txt`** with a one-paragraph explanation.
  run_all_tests.sh re-runs the miter on every entry and auto-buckets it 🔬
  ARTEFACT — so an EQUIVALENT miter needs NOTHING else. Use the test's basename
  (e.g. `code_hdl_models_pri_encoder_using_assign`), matching the existing
  entries. Typical artefacts: `== <const with x bits>` (synth wildcard vs
  Verilator 4-state x), latch/FF X-init, other x-propagation.
- **Real UHDM bug (miter NON-EQUIVALENT, or UHDM-cosim FAIL + Verilog-cosim
  PASS)** → add it to **`test/sim_equiv_analyzed.txt`** (keeps the suite green)
  AND to the bug backlog **`test/cosim_uhdm_bugs.txt`** AND list it expected-fail
  in **`test/failing_tests.txt`** (internal name and/or yosys path). Fix one
  isolated change at a time, then REMOVE it from all three.
- **Miter INCONCLUSIVE (satgen can't model the cells — `$_DLATCH_`, abc9
  MUXF7/LUT, SVA `$check`; or a reset-dependent false NON-EQ)** → the auto-
  classifier can't decide, so add a manual override line to
  **`test/sim_equiv_classification.txt`**: `<basename>  <artefact|bug>  # reason`.
  An override WINS over the miter. Still also add the `sim_equiv_analyzed.txt`
  entry. (Before calling it inconclusive, try isolating the unmodellable cell —
  e.g. drop a `$pow`/`$div`-bearing mode — so the miter can run on the rest.)

Don't invent or rename test files from training data — only touch the four
above, and confirm the basename matches how run_all_tests.sh reports the test.
