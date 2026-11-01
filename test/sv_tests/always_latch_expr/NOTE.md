CONVERTED, and gated on the netlist SHAPE plus read_verilog.

The claim is that an `always_latch` with an incomplete assignment becomes a
LEVEL-SENSITIVE latch -- enable `a`, data `b` -- rather than a mux or a flop.
A miter cannot gate it: `sat` refuses the latch cell outright
(`No SAT model available for async FF cell ... ($ff)`) and, with the state
unconstrained at cycle 0, any latch satisfies it anyway.  The shape assertion is
the real check and the uhdm-vs-verilog comparison covers the logic.
