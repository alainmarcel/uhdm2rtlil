CONVERTED, and gated on the netlist SHAPE plus read_verilog.

The claim is that the block becomes exactly ONE edge-triggered register wired
clk -> CLK, b -> D, q -> Q.  A value proof is the wrong gate for it: `sat -seq N
-prove` checks the property in EVERY step, including step 1 before any clock
edge, where the register is still unwritten -- it fails on read_verilog and
read_slang too.  A miter is no better, because `sat` starts from an
unconstrained state and both sides satisfy it regardless.  The
uhdm-vs-verilog comparison covers the register's logic.
