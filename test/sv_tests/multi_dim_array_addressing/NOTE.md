CONVERTED, and gated on the netlist SHAPE plus read_verilog.

A memory miter is never a gate (free contents at cycle 0), so the claim is the
shape.  The count is a minimum because a 2-D array may legitimately be lowered to
one memory or to one per outer index.
