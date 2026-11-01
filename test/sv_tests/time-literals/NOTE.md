RATCHET -- TIME LITERALS are not scaled to the module's time unit.

Under `timescale 100ps/10ps`, 1ns is 10 units, 1us is 10000, 1ms is 10000000 and
the real 2.1ms rounds to 21000000.  read_slang gives exactly those; read_uhdm
gives 1000000 / 1000 / 1000000000 / 2000000000 -- not a consistent unit at all
(1ns comes out LARGER than 1us).  read_verilog cannot parse the literals.  The fs
and ps literals are below the unit and round to 0, so they are not proven.
Listed in structural_expected_fail.txt and slang_miter_expected_fail.txt.
