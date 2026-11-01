CONVERTED, and gated on the netlist SHAPE plus read_verilog.

A register's behaviour is invisible to a miter that starts from an unconstrained
state -- both sides satisfy it regardless -- and `sat -seq N -prove` checks the
property in EVERY step including step 1, before any edge, where it fails on
read_verilog and read_slang too.  So the claim is structural: the block must
become an edge-triggered register wired to the clock.  The uhdm-vs-verilog
comparison covers the logic itself.
