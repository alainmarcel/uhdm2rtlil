NOT SYNTHESIZABLE -- classified, not converted.

Class: chandle
A `chandle` is an opaque pointer to foreign (DPI) data: there is nothing to elaborate.

Upstream evidence:
    module top();
    	chandle a;
    endmodule

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
