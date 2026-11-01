NOT SYNTHESIZABLE -- classified, not converted.

Class: intra-assignment timing control
An intra-assignment delay, repeat or event control schedules WHEN the write lands, which synthesis discards entirely.

Upstream evidence:
    	initial begin
    		a = repeat(-3) @(posedge clk) b;
    	end

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
