// YosysHQ/yosys#4873 (closed): 'show -format dot' fails on a .sv file
// https://github.com/YosysHQ/yosys/issues/4873
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module and_gate (
    input  logic a,
    input  logic b,
    output logic s
);

  assign s = a & b;

endmodule

