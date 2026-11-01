NOT SYNTHESIZABLE -- classified, not converted.

Class: delay control
The behaviour under test is a DELAY, which synthesis discards.

Upstream evidence:
    	i = 1;
    	#100 i = 2;
    	#200 $dumpoff;

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
