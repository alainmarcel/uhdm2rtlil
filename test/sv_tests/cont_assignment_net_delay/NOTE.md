CONVERTED, and gated on `read_verilog` rather than `read_slang`.

`read_slang` cannot read a DELAY on a continuous assignment or a net
(`unsupported system task`), so a miter against it is not a gate -- it would fail
for a reason that is not ours.  `read_verilog` reads it and the uhdm-vs-verilog
comparison plus the structural proof are this test's gates.  Synthesis discards
the delay; what the test claims is that the delay is ACCEPTED and does not change
what the logic computes, which is all a netlist can show.
