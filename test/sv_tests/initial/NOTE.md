CONVERTED, and gated on the netlist SHAPE plus read_verilog.

An `initial` value is a POWER-UP value, which a miter cannot see: `prep` leaves it
as the wire's `init` attribute and `sat` starts from an unconstrained state, so
both sides satisfy any miter regardless of the attribute.  The claim is therefore
structural -- the attribute must be there with the value 1 -- which read_verilog,
read_slang and read_uhdm all produce (measured 2026-10-31), and the
uhdm-vs-verilog comparison covers the register itself.
