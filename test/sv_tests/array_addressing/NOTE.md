CONVERTED, and gated on the netlist SHAPE plus read_verilog, not on a miter.

A miter over a 1024-entry memory is not a gate.  `memory_map` expands it to 8192
flops on each side and `sat` then refuses them
(`No SAT model available for async FF cell ... ($dff)`), and left as `$mem_v2`
the solver has no model for the cell at all.  A sequential miter does not help
either: the two sides' memory CONTENTS are free variables at cycle 0 and need not
agree, so the proof fails for a reason that is not a frontend difference.  What
this test claims is the netlist SHAPE -- a port-addressed 1024-entry array must
become one memory, not 1024 muxes -- which test_structural.ys asserts directly,
and read_verilog produces the same shape.
