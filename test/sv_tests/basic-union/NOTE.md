CONVERTED, and gated on read_uhdm's own proof plus read_verilog.

`read_slang` refuses to read it: `value of type 'union' is unsupported for
conversion to bits in this context` -- an UNPACKED union's members cannot be
bit-converted there -- so a miter against it is not a gate.  `read_verilog`
cannot read it either (an unpacked union is not Verilog-2005), so this test's
gate is its test_structural.ys, which proves both the wide member's round trip
and the narrow member aliasing the LOW bits.
