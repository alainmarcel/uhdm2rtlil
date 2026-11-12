// povik/sv-elab#67 (open): Support ports w/o direct correspondence to a net/variable
// https://github.com/povik/sv-elab/issues/67
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module mymod (
	output .p1(r[3:0]),
	output .p2(r[7:4]));
logic [7:0] r;
endmodule

