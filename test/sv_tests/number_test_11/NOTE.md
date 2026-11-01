RATCHET-ADJACENT -- the same sign/fill-EXTENSION defect as number_test_9, in its
x/z form, but this test's gates cannot see it.

`parameter int foo = 1 'b x;` must ZERO-extend into the 32-bit `int`, leaving the
literal's own bits at the bottom.  Measured 2026-11-01:

    read_verilog : 32'0000000000000000000000000000000x
    read_uhdm    : 32'-------------------------------- (all don't-care)

So read_uhdm extends the x (or z) bit across the WHOLE width instead of
zero-extending -- the same wrong path that turns `1'b1` into all-ones
(see number_test_9/NOTE.md, which carries the full measured table).

Why this test is not in the ratchet lists: `sat -verify -prove` takes a two-state
constant, so the value cannot be proven; `read_slang` normalises x/z differently
again (it reports 0 for `4'bxxxx`), so the miter is not a reference; and the
netlist is pure wiring, so the workflow's gate-count comparison reports
"functionally equivalent" on ZERO gates.  `number_test_13` is the one case where
the Induct-Formal check does fire, so that is the entry that ratchets this
defect's x/z half -- fix it and this test's measurement changes with it.
