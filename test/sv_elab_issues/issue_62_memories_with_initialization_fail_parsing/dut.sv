// povik/sv-elab#62 (closed): Memories with initialization fail parsing
// https://github.com/povik/sv-elab/issues/62
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top();
	reg [7:0] m[2];
	initial m[0] <= 0;
endmodule

