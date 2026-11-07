// YosysHQ/yosys#4112 (closed): Bug with modulo in CXXRTL when operands intersect
// https://github.com/YosysHQ/yosys/issues/4112
// Code block(s) from the issue (variant v1); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top(
    input logic [63:0] in_data,
    output logic [63:0] out_data
);
    assign out_data = in_data[63:32] % in_data[31:0];
endmodule

