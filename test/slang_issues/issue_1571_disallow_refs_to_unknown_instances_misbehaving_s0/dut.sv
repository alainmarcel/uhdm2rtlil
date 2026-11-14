// MikePopoloski/slang#1571 (closed): `--disallow-refs-to-unknown-instances` misbehaving in uninstantiated modules
// https://github.com/MikePopoloski/slang/issues/1571
// Code block(s) from the issue (variant s0); harvested by test/slang_issues/harvest.py

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

