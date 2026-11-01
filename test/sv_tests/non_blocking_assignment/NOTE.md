CONVERTED, and gated on the netlist SHAPE plus read_verilog.

A register is invisible to a miter that starts from an unconstrained state, and
`sat -seq N -prove` checks step 1 before any clock edge (it fails on read_verilog
and read_slang too).  The claim is therefore structural: one edge-triggered
register wired clk -> CLK and the source -> D.  The uhdm-vs-verilog comparison
covers the truncation itself.
