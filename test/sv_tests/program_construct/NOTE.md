NOT SYNTHESIZABLE -- classified, not converted.

Class: program block
A `program` block is a testbench construct, not hardware.

Upstream evidence:
    program prog(input wire a, input wire b);
    	initial $display(":assert: (%d == %d)", a, b);

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
