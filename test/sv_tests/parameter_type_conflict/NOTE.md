NOT SYNTHESIZABLE -- classified, not converted.

Class: class
Classes are dynamically allocated objects: there is nothing for synthesis to elaborate.

Upstream evidence:
    	
    	interface class ic3#(type TYPE = logic) extends ic1#(TYPE), ic2#(TYPE);
    		typedef TYPE T;

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
