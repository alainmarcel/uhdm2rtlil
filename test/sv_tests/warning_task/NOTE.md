NOT SYNTHESIZABLE -- classified, not converted.

Class: simulation control task
A simulation control or reporting task ends, pauses or instruments the RUN; there is no netlist counterpart.

Upstream evidence:
    initial begin
    	$warning("warning");
    end

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
