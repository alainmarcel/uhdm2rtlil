CONVERTED, and gated on the netlist SHAPE plus read_verilog.

A miter over a memory is not a gate: the two sides' contents are free variables
at cycle 0, so the proof fails for a reason that is not a frontend difference
(measured on read_verilog too).  The claim is the SHAPE -- one memory, not 256
registers -- which read_verilog produces as well.
