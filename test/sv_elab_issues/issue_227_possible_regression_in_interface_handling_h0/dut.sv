// povik/sv-elab#227 (closed): Possible regression in interface handling
// https://github.com/povik/sv-elab/issues/227
// Code block(s) from the issue (variant h0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
interface bus(input clk);
	logic a, b;
	modport primary(input a, output b, input clk);
	modport secondary(input b, output a, input clk);
endinterface

module submod(bus.primary intf);
	assign intf.b = !intf.a;
endmodule

module top(input logic w1, output logic w2,
		   input logic clk);
	bus intf(clk);
	assign intf.a = w1;
	assign w2 = intf.b;
	submod sm(intf);
endmodule

module top2();
endmodule

