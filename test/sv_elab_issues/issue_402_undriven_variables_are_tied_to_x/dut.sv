// povik/sv-elab#402 (open): Undriven variables are tied to 'x, so a formal flow sees one independent free value per reader
// https://github.com/povik/sv-elab/issues/402
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module child (input logic clk, input logic rst, input logic [5:0] x);
  always @(posedge clk) if (!rst) begin : x_range_a assert (x < 43); end
endmodule

module top (input logic clk, input logic rst);
  logic [5:0] x;   // undriven: meant as one free variable for the formal tool
  always @(posedge clk) if (!rst) begin : x_range_m assume (x < 43); end
  child c0 (.clk, .rst, .x);
  child c1 (.clk, .rst, .x);
endmodule

