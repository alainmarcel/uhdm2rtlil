NOT SYNTHESIZABLE -- classified, not converted.

Class: event variable
An `event` is a synchronisation object triggered and waited on at simulation time.

Upstream evidence:
    module top();
    	event a;
    endmodule

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
