// povik/sv-elab#413 (open): Formal `$check` cells are not marked `keep`, so `opt_merge` merges identical assertions and drops their labels
// https://github.com/povik/sv-elab/issues/413
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top(input logic clk, input logic a, input logic b);
  always_ff @(posedge clk) begin
    as_first: assert (a == b);
  end
  always_ff @(posedge clk) begin
    as_second: assert (a == b);
  end
endmodule

