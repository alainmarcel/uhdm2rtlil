NOT SYNTHESIZABLE -- classified, not converted.

Class: clocking block
A `clocking` block schedules testbench sampling; it is not hardware.

Upstream evidence:
    module top(input clk);
    
    default clocking @(posedge clk);

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
