CONVERTED, and gated on the netlist SHAPE plus read_verilog.

As for `array_addressing_sim`: with `we` held low the element is never written, so
`sat` reads it as a free value and a value proof succeeds VACUOUSLY -- measured on
read_verilog too.  The claim is therefore structural.
