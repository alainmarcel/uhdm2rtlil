NOT SYNTHESIZABLE -- classified, not converted.

Class: global clocking
A `global clocking` block names a simulation sampling clock; it declares no hardware.

Upstream evidence:
    module top(input clk);
    
    global clocking ck1 @(posedge clk); endclocking

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
