// MikePopoloski/slang#1152 (closed): Translating indices when connecting an array of interfaces on a port
// https://github.com/MikePopoloski/slang/issues/1152
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
interface bus();
	logic a;
	logic b;
endinterface

module submodule(bus iface [3:2]);
	assign iface[2].a = iface[3].b;
endmodule

module top();
	bus iface[1:0]();
	submodule inst(iface);
endmodule

