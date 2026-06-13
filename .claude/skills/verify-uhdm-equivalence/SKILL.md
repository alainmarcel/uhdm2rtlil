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
  here is suggestive, not proof.
- **Blind spot — async FFs / public gate types**: on Yosys 0.64 it can abort
  with "No SAT model available for cell …". That is a flow limitation, not a
  frontend bug — fall through to tool 4 (the miter handles it).

### 4. Sound triage — `python3 triage_cosim.py <name> [--seq N] [--cycles N]`
The discriminator. Runs TWO independent sound-ish checks and prints a verdict:
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
