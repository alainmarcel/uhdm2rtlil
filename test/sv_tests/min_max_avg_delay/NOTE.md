NOT SYNTHESIZABLE -- classified, not converted.

Class: min:typ:max delay
A min:typ:max delay triple is a timing annotation with no netlist form.

Upstream evidence:
    initial begin
    	#(100:200:300) $display("Done");
    end

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
