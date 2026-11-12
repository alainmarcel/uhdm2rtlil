// povik/sv-elab#372 (closed): Unsigned comparison treated as signed
// https://github.com/povik/sv-elab/issues/372
// Code block(s) from the issue (variant v0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top (input logic [3:0] x, output logic y);
  assign y = (x < 8'hEE);   // x is at most 15, so this is always 1; 0xEE = 238 in decimal
endmodule

