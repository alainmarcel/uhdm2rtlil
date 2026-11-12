// povik/sv-elab#33 (closed): Bit-typed variables with unpacked dimensions crash the frontend
// https://github.com/povik/sv-elab/issues/33
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top ();

bit _bit [7:0];
logic _logic [7:0];
reg _reg [7:0];

endmodule

