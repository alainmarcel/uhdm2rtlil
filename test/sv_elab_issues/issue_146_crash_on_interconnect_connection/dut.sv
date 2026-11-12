// povik/sv-elab#146 (closed): Crash on `interconnect` connection
// https://github.com/povik/sv-elab/issues/146
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top();
	interconnect bus;
	m mi(bus);
endmodule

module m(input x);
endmodule

