CONVERTED, and gated on the netlist SHAPE plus read_slang's own read.

`read_verilog` cannot parse `always @(posedge clk iff ...)` at all, so the golden
comparison is unavailable, and a register is invisible to a miter from an
unconstrained state.  The claim is therefore structural: the qualified edge must
produce a register whose enable cone contains `en` and whose clock cone contains
`clk` -- a frontend that dropped the `iff` would leave `en` out of the netlist
entirely.
