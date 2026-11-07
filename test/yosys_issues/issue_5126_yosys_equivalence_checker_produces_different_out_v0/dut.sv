// YosysHQ/yosys#5126 (closed): Yosys equivalence checker produces different outcomes depending on the name of internal variable
// https://github.com/YosysHQ/yosys/issues/5126
// Code block(s) from the issue (variant v0); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module adder_small(clk, enable, rst, a, b, enable2, sum2);
  input wire a;
  input wire b;
  input wire clk;
  input wire enable;
  input wire rst;
  output logic enable2;
  output logic sum2;
  logic spec__02_;
  logic spec__03_;
  wire c0;
  logic sum;
  assign spec__03_ = enable | rst;
  always_ff @(posedge clk)
    enable2 <= enable;
  assign c0 = a + b;
  always_ff @(posedge clk)
    if (spec__03_) sum <= c0;
  assign spec__02_ = enable2 | rst;
  always_ff @(posedge clk)
    if (spec__02_) sum2 <= sum;
endmodule

