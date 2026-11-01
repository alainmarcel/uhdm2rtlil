// Converted from chipsalliance/sv-tests (variable_assignment).
// Upstream continuously assigns a constant to an `int` VARIABLE and never reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] o);
	int v;
  // A continuous assign to a VARIABLE (not a net) is legal in SystemVerilog.
	assign v = x + 12;
  assign o = v;
endmodule
