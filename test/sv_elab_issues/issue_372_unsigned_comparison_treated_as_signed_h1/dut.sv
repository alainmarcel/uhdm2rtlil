// povik/sv-elab#372 (closed): Unsigned comparison treated as signed
// https://github.com/povik/sv-elab/issues/372
// Code block(s) from the issue (variant h1); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top (input logic [3:0] x, output logic y);
  assign y = (x < 8'bX0001000);
endmodule

