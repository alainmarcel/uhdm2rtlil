// povik/sv-elab#401 (open): Async load with OR
// https://github.com/povik/sv-elab/issues/401
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top(input clk, input rst_a, input rst_b, input d, output reg q);
  always @(posedge clk or negedge rst_a or negedge rst_b)
    if (!rst_a || !rst_b) q <= 1'b1;
    else q <= d;
endmodule

