NOT SYNTHESIZABLE -- classified, not converted.

Class: SVA property / sequence
A `property` or `sequence` with temporal operators (`|->`, `##n`, `[*n]`, `[->n]`, `[=n]`, `disable iff`) describes behaviour over TIME.  The three frontends emit no netlist cell for the deferred, `final` and concurrent forms (measured 2026-10-31 for the assertion group), so there is nothing a proof can read.

Upstream evidence:
    assert property (...)

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
