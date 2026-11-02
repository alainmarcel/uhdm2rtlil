FIXED 2026-11-01 -- the same sign/fill-EXTENSION defect as number_test_9, in its
x/z form; this test's gates could not see it, so the measurement is kept here.

`parameter int foo = 1'bx;` must ZERO-extend into the 32-bit `int`, leaving the
literal's own bits at the bottom.  Measured 2026-11-01, before the fix:

    read_verilog : 32'0000000000000000000000000000000x
    read_uhdm    : 32'-------------------------------- (all don't-care)

read_uhdm extended the x (or z) bit across the WHOLE width -- the reader
replicated any 1-bit constant to the LHS width (a path meant for `'1` fills) and
sign-extended a wider one off the typespec Surelog stamps on a folded literal.
After the fix read_uhdm gives 32'0000000000000000000000000000000x, the read_verilog value.

Why this test is not in the ratchet lists: `sat -verify -prove` takes a two-state
constant, so the value cannot be proven; `read_slang` normalises x/z differently
again (it reports 0 for `4'bxxxx`), so the miter is not a reference; and the
netlist is pure wiring, so the workflow's gate-count comparison reports
"functionally equivalent" on ZERO gates.  `number_test_13` is the one case where
the Induct-Formal check fires, so that was the entry that ratcheted the x/z half;
see number_test_9/NOTE.md for the two root causes.
