// Converted from chipsalliance/sv-tests (typedef).
// Upstream declares a typedef inside the module and a variable of it, and never drives or reads the variable.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic x, output logic a_o, output logic signed [31:0] nbits);
	typedef logic logic_t;
	logic_t a;
  always_comb a = x;
  assign a_o   = a;
  assign nbits = $bits(logic_t);
endmodule
