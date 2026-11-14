// MikePopoloski/slang#1492 (closed): Named instance connections don't include correct source location for the expression.
// https://github.com/MikePopoloski/slang/issues/1492
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module passthrough (
  input clk,
  input rst,
  input in,
  output logic out
);
endmodule

module top (__i_clk, __i_in, __i_rstb, __o_out);
logic clk, rstb;
logic in, out;

passthrough pt (
  .clk,
  .rst (!rstb),
  .*
);


  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_clk;
  assign clk = __i_clk;
  input logic __i_in;
  assign in = __i_in;
  input logic __i_rstb;
  assign rstb = __i_rstb;
  output logic __o_out;
  assign __o_out = out;
endmodule

