// YosysHQ/yosys#4653 (closed): SystemVerilog packed structs not supported
// https://github.com/YosysHQ/yosys/issues/4653
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
typedef struct packed {
	logic y;
	logic x;
} Vec_2_B;

module Gpu (output logic mixed_sync);
endmodule

(* top *)
module Top(output Vec_2_B vga_sync);

	Gpu gpu(vga_sync.x);

endmodule

