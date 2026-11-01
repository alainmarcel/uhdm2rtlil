CONVERTED, with the literal's value out of reach of a proof.

This literal has x or z bits and `sat -verify -prove` takes a two-state constant,
so the parameter's value cannot be the subject of a proof.  It is still an OUTPUT,
and the uhdm-vs-`read_verilog` netlist comparison compares x and z exactly, so the
value IS gated -- just not by SAT.  The witness output is proven so the co-sim has
activity to compare (a netlist whose every output is a constant is reported
VACUOUS).

`read_slang` is not a reference here either: it normalises z to x, so a miter
against it fails on a difference that is not ours.  read_verilog agrees with
read_uhdm on x and z and is this test's reference.
