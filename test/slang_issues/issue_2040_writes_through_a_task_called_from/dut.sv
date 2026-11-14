// MikePopoloski/slang#2040 (closed): Writes through a task called from another process are not checked against always_comb and always_ff
// https://github.com/MikePopoloski/slang/issues/2040
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__i_clk, __o_q, __o_t);
  logic clk;
  logic [7:0] a, t, q;
  task automatic set_t(input logic [7:0] v);
    t = v;
  endtask
  task automatic set_q(input logic [7:0] v);
    q = v;
  endtask
  always_comb t = a;
  always_ff @(posedge clk) q <= a;
  initial begin
    set_t(8'd7);
    set_q(8'd7);
  end

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_clk;
  assign clk = __i_clk;
  output logic [7:0] __o_q;
  assign __o_q = q;
  output logic [7:0] __o_t;
  assign __o_t = t;
endmodule

