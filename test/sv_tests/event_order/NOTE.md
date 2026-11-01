NOT SYNTHESIZABLE -- classified, not converted.

Class: fork/join
Dynamic process control has no netlist form.

Upstream evidence:
    	reg [3:0] a = 0;
    	initial fork
    		begin

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
