// MikePopoloski/slang#932 (closed): slang refuses always_ff with non blocking assignment and delay
// https://github.com/MikePopoloski/slang/issues/932
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
`define D #1
module x (__i_clk, __o_a);
reg a;
wire clk;
always_ff @(posedge clk)
  a <= `D 1'b0;

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_clk;
  assign clk = __i_clk;
  output logic __o_a;
  assign __o_a = a;
endmodule

