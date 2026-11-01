NOT SYNTHESIZABLE -- classified, not converted.

Class: real variable
A `real` / `realtime` / `shortreal` VARIABLE (or a `var type(...)` over
reals) has no netlist form: synthesis has no floating-point datapath.  What IS
synthesizable is real arithmetic folded at ELABORATION -- a real parameter, a
real literal assigned to an integral target, `$rtoi`/`$itor`, `$clog2`
and the other constant system functions -- and those tests (parameter_real,
real-constants, rtoi_function, itor_function, cast_op, ceil_function, ...) are
converted.  This one declares a real variable, which is the part with no
hardware meaning.

Upstream evidence:
    module top();
    	realtime a = 0.5;
    endmodule

A first conversion attempt treated this as a reader defect ("the initialiser is
dropped, the variable reads x"); it is not -- there is nothing a netlist can carry
for the variable in the first place.  Reclassified 2026-11-01.
