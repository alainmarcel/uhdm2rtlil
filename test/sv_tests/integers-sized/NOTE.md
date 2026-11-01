CONVERTED, with the x/z bits out of reach of a proof.

Some of the literals in this test have x or z bits, which `sat -verify -prove`
cannot express: a proof constant is two-state.  The proofs below therefore pin
the DEFINED bits of each literal (the padding behaviour that upstream's comments
assert), and the x/z bits are covered instead by the uhdm-vs-`read_verilog`
netlist comparison, which compares them exactly.

`read_slang` is NOT a reference for the x/z bits: it normalises z to x (`'h 0z3`
reads back as `0000xxxx0011` where read_verilog and read_uhdm both give
`0000zzzz0011`), so a miter against it fails on a difference that is not ours.
read_verilog agrees with read_uhdm and is this test's reference.
