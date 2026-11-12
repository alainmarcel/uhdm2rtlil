// povik/sv-elab#56 (open): lack of warnings/errors for unwanted latches
// https://github.com/povik/sv-elab/issues/56
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module test1 (input logic a, b, output logic y);
always_comb begin
  if (a)
    y = b;
end
endmodule

