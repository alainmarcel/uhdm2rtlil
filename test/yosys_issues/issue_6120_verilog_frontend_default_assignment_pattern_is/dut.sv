// YosysHQ/yosys#6120 (open): Verilog frontend: `'{default: ...}` assignment pattern is a syntax error
// https://github.com/YosysHQ/yosys/issues/6120
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
// t.sv
module t (input logic [31:0] d, output logic [31:0] q);
  logic [31:0] m [0:3];
  assign m = '{default: 32'h0};
  assign q = m[0] ^ d;
endmodule

