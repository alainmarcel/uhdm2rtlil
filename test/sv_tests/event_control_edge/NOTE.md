NOT SYNTHESIZABLE -- classified, not converted.

Class: dual-edge sensitivity
A dual-edge sensitivity (`@(edge clk)`) describes a flop no frontend builds: read_verilog cannot parse the form, read_slang refuses it (`@(edge) will not be synthesized`) and read_uhdm refuses it too, so there is no netlist to claim.

Upstream evidence:
    	wire clk = 0;
    	always @(edge clk) a = ~a;
    endmodule

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
