// YosysHQ/yosys#2846 (closed): User defined types declared with initializer use continuous instead of procedural assignment
// https://github.com/YosysHQ/yosys/issues/2846
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): co-sim top module top_all instantiates top_1/top_2/top_3 (top_3 alone has a constant output); the three variants are unchanged

// ---- b0.sv
module top_1 (
    input  logic clk,
    input  logic in,
    output logic out
);
  typedef logic user_t;

  user_t var_0 = 0;

  always_ff @(posedge clk) begin
    var_0 <= in;
  end

  assign out = var_0;
endmodule

// ---- b1.sv
module top_2 (
    input  logic clk,
    input  logic in,
    output logic out
);
  typedef logic user_t;

  user_t var_0;

  initial var_0 = 0;

  always_ff @(posedge clk) begin
    var_0 <= in;
  end

  assign out = var_0;
endmodule

// ---- b2.sv
module top_3 (
    input  logic clk,
    input  logic in,
    output logic out
);
  typedef logic user_t;

  user_t var_0;

  assign var_0 = 0;

  always_ff @(posedge clk) begin
    var_0 <= in;
  end

  assign out = var_0;
endmodule

// co-sim top: all three variants side by side (the last module, top_3, alone
// is constant -- its `assign var_0 = 0` competes with the always_ff)
module top_all (input logic clk, input logic in, output logic out1, out2, out3);
  top_1 u1 (.clk(clk), .in(in), .out(out1));
  top_2 u2 (.clk(clk), .in(in), .out(out2));
  top_3 u3 (.clk(clk), .in(in), .out(out3));
endmodule
