// YosysHQ/yosys#2348 (closed): SystemVerilog structs cannot be used in module arguments
// https://github.com/YosysHQ/yosys/issues/2348
// Code block(s) from the issue (variant v0_tc); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
typedef struct packed {
	reg foo;
} bar;

module baz (
	input bar b,
	output wire qux
);

	assign qux = b.foo;
endmodule

