// YosysHQ/yosys#5126 (closed): Yosys equivalence checker produces different outcomes depending on the name of internal variable
// https://github.com/YosysHQ/yosys/issues/5126
// Code block(s) from the issue (variant v1); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module adder_small(clk, enable, rst, a, b, enable2, sum2);
  input wire a;
  input wire b;
  input wire clk;
  input wire enable;
  input wire rst;
  output logic enable2;
  output logic sum2;
  reg _00_;
  reg _01_;
  logic impl__02_;
  logic impl__03_;
  logic sum;
  assign impl__03_ = enable | rst;
  always_ff @(posedge clk)
    enable2 <= enable;
  always_ff @(posedge clk)
    if (impl__03_) _01_ <= a;
  always_ff @(posedge clk)
    if (impl__03_) _00_ <= b;
  assign sum = _01_ + _00_;
  assign impl__02_ = enable2 | rst;
  always_ff @(posedge clk)
    if (impl__02_) sum2 <= sum;
endmodule

