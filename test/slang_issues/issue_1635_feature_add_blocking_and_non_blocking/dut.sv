// MikePopoloski/slang#1635 (closed): [feature] add blocking and non-blocking diagnostic error
// https://github.com/MikePopoloski/slang/issues/1635
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module TestModule (__i_clk, __i_reset, __o_test);
  struct {
    logic a;
    logic b;
  } test;

  always_comb begin
    test.a = 1'b0;
  end

  always_ff @(posedge clk or posedge reset) begin
    test.b <= 1'b1;
  end

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_clk;
  assign clk = __i_clk;
  input logic __i_reset;
  assign reset = __i_reset;
  output logic [1:0] __o_test;
  assign __o_test = test;
endmodule

