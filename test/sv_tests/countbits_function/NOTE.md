FIXED 2026-11-02 (was a RATCHET): -- the construct is NOT implemented by read_uhdm.

`$countones` and `$countbits` are unhandled: the reader warns
`Unhandled system function call: $countones with 1 arguments` and then returns the
OPERAND, so at 32'h70008421 every output reads 1879082017 (the argument) instead
of 7 / 25 / 32 / 0.  `read_verilog` computes all five correctly and is the oracle,
so this test's `test_structural.ys` is listed in structural_expected_fail.txt and
must be removed from it in the commit that implements the functions.

`read_slang` is NOT a reference here -- it refuses outright
(`unsupported system task '$countbits'`) -- so there is no slang miter.
