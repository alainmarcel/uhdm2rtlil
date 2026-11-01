CONVERTED, and gated on the netlist SHAPE plus read_verilog.

`read_slang` cannot read the radix forms (`unsupported system task '$displayb'`),
so there is no miter.  read_verilog and read_uhdm both emit three `$print` cells
(measured 2026-10-31), so the count is the claim; the cells are deleted before
the value proof because a `$print` has no SAT model.
