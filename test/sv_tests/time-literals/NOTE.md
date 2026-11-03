FIXED 2026-11-02 (was a RATCHET) -- TIME LITERALS were not scaled to the module's
time unit.  Surelog, not the reader: the literal was parsed as an integer (2.1 ->
2), converted to picoseconds with the ns and us factors SWAPPED, and never related
to the module's `timescale` at all.

Under `timescale 100ps/10ps`, 1ns is 10 units, 1us is 10000, 1ms is 10000000 and
the real 2.1ms rounds to 21000000.  read_slang gives exactly those; read_uhdm
used to give 1000000 / 1000 / 1000000000 / 2000000000 -- not a consistent unit at
all (1ns came out LARGER than 1us).  read_verilog cannot parse the literals.  The
fs and ps literals are below the unit and round to 0, so they are not proven.
