// povik/sv-elab#167 (open): Support for `force`-`release`
// https://github.com/povik/sv-elab/issues/167
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module flop(clk, q, d);

input clk, d;
output q;
logic q;

always @(posedge clk)
  q <= d;

endmodule

module top(clk, q, d, f1, f0);

input clk, d, f1, f0;
output q;
wire q;

flop u_flop (.*);

always @(f1 or f0)
  if (f0)
    force u_flop.q = 0;
  else if (f1)
    force u_flop.q = 1;
  else
    release u_flop.q;

endmodule

