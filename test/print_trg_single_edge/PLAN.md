# `$print` / `$check` edge-trigger support — Multi-PR Plan

Tracker for unblocking `yosys/tests/various/clk2fflogic_effects.sv`,
which exercises edge-triggered `$display` semantics across thirteen
`always @(<edge-list>)` blocks.  Our frontend currently emits
`$print` cells with no trigger, so `synth` dead-strips all
producer logic and the design ends up with zero gates.  The
upstream test passes `iverilog sim` vs `yosys sim` text-log diff;
our formal-equivalence flow can't reach that, but it CAN compare
synth gate counts — and that's what currently fails.

## PR 1: `$print` TRG binding for single-edge always blocks — IN PROGRESS

**Symptom**: `always @(posedge clk) if (cond) $display(...)` lowers
to a `$print` cell with `TRG_ENABLE = 0` (combinational) and
`EN = 0` (default).  `synth` sees the cell as dead and removes the
condition-computing logic.

**Root cause**: `import_display_stmt` always emits
`TRG_ENABLE = 0` and an empty `TRG` port, regardless of whether the
surrounding `always_ff` block has a clock signal.

**Fix**: when `in_always_ff_context && !current_ff_clock_sig.empty()`,
bind `TRG = current_ff_clock_sig`, `TRG_ENABLE = 1`,
`TRG_POLARITY = 1` (posedge).  Mirrors `build_check_cell`'s
existing handling for `$check`.

**Repro**: this directory (`test/print_trg_single_edge/`).

## PR 2: Route multi-edge non-reset always blocks — ✅ DONE

**Symptom**: `always @(posedge a, posedge b) if (en) $display(...)`
emits no `$print` cell at all.  Trigger signals (`eff_1_*` /
`eff_2_*` in clk2fflogic_effects.sv) get dead-stripped.

**Root cause**: `import_always_ff`'s async-reset path matched only
`vpiIfElse` bodies (`if (rst) ... else ...`).  A bare `if (cond)
$display(...)` is `vpiIfStmt` (no else), and the path silently
dropped it — the resulting process had empty body with only sync
rules.

**Fix**: when `assigned_signals` is empty AND no `vpiIfElse` body
was matched, set `in_always_ff_context = true` /
`current_ff_clock_sig = clock_sig` and call
`import_statement_comb(stmt, &yosys_proc->root_case)` directly on
the body.  Effect-only bodies (`$display` / `$check` calls) emit
`$print`/`$check` cells with TRG bound; no temp wires or sync
rules needed.

**Repro**: `test/print_trg_multi_edge/`.

## PR 3: Multi-trigger `$print` cell emission — PENDING

**Symptom**: even with PR2's routing, `$print` cells emitted inside
a multi-edge always block still bind a single trigger; the second
edge isn't connected.

**Root cause**: `import_display_stmt` reads
`current_ff_clock_sig` which is a single `SigSpec`, set during
single-edge processing.  Multi-edge always blocks need
`TRG = concat(sig0, sig1, ...)`, `TRG_POLARITY = Const(per-bit
polarities)`, `TRG_WIDTH = N`.

**Fix plan**: introduce `current_ff_edges` (a vector of
`(SigSpec, bool posedge)`), populated alongside
`current_ff_clock_sig` for multi-edge sensitivities.
`import_display_stmt` (and `build_check_cell`) emit multi-bit TRG
when this vector has >1 entry.  Repro to write:
`test/print_trg_mixed_edges/dut.sv`.

## PR 4: `clk2fflogic_effects.sv` end-to-end pass — PENDING

Copy the upstream file into `test/clk2fflogic_effects/`, confirm
formal equivalence passes end-to-end.  Possible residual issues:
`$finish` inside `__ICARUS__` guards (which Surelog skips), and
the `(* gclk *)` attribute on a bare reg (already works).

## Status

| PR | Issue | Status |
|----|-------|--------|
| 1 | `$print` TRG binding for single-edge | merged |
| 2 | Route multi-edge non-reset always | this PR |
| 3 | Multi-trigger `$print` cells | pending |
| 4 | clk2fflogic_effects end-to-end | pending |
