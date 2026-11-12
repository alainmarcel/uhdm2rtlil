// povik/sv-elab#395 (closed): ORFS ariane design fails, should work with `--compat=vcs`
// https://github.com/povik/sv-elab/issues/395
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module controller (clk, q);
  input clk;
  output q;
  wire q, q;
  reg r;
  always @(posedge clk) r <= ~r;
  assign q = r;
endmodule
module top (clk, b);
  input clk;
  output b;
  controller controller_i (.clk(clk), .q(b));
endmodule

