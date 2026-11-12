// povik/sv-elab#142 (closed): yosys-slang appears to ignore register initial value
// https://github.com/povik/sv-elab/issues/142
// Code block(s) from the issue (variant h0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top(output [7:0] y);
	sm sm(.y(y));
endmodule

module sm(output [7:0] y);
	reg [7:0] r = 94; 
	assign y = r;
endmodule

