// povik/sv-elab#146 (closed): Crash on `interconnect` connection
// https://github.com/povik/sv-elab/issues/146
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top(__i_bus);
	interconnect bus;
	m mi(bus);

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_bus;
  assign bus = __i_bus;
endmodule

module m(input x);
endmodule

