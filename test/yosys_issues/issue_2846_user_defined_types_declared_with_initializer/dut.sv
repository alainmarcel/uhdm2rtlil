// YosysHQ/yosys#2846 (closed): User defined types declared with initializer use continuous instead of procedural assignment
// https://github.com/YosysHQ/yosys/issues/2846
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

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

