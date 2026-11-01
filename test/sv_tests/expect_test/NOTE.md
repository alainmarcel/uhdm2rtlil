NOT SYNTHESIZABLE -- classified, not converted.

Class: SVA expect
`expect` blocks the executing process until a sequence matches: it is a testbench construct with no netlist form.

Upstream evidence:
    initial begin
        expect (@(posedge clk) a ##1 b);
    end

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
