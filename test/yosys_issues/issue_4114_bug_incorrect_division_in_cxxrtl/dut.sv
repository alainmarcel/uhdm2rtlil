// YosysHQ/yosys#4114 (closed): Bug: incorrect division in CXXRTL
// https://github.com/YosysHQ/yosys/issues/4114
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top(
    input logic [63:0] in_data,
    output logic [63:0] out_data
);
    assign out_data = in_data[41:6] / in_data[63:28];
endmodule

