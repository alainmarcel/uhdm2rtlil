// YosysHQ/yosys#2348 (closed): SystemVerilog structs cannot be used in module arguments
// https://github.com/YosysHQ/yosys/issues/2348
// Code block(s) from the issue (variant v1_tc); harvested by test/yosys_issues/harvest.py
// HAND-EDITED (keep on re-harvest): wrapper top added: the interface-port module cannot be a co-sim top

// ---- b0.sv
typedef struct packed {
	reg foo;
} bar;

interface wrapper;
	bar b;
endinterface

module baz (
	wrapper w,
	output wire qux
);

	assign qux = w.b.foo;
endmodule

module top (input wire d, output wire qux);
	wrapper w();
	assign w.b.foo = d;
	baz u (.w(w), .qux(qux));
endmodule
