CONVERTED, and gated on the netlist SHAPE plus read_verilog.

A `$print` cell has no SAT model, so a miter over it is not a gate.  All three
frontends emit exactly one `$print` for this `$display` (measured 2026-10-31), so
the count is the claim, and the uhdm-vs-verilog comparison covers the rest.
