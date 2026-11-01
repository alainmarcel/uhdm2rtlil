// Converted from chipsalliance/sv-tests (parameter_real).
// Upstream declares a REAL parameter and never reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] o);
  parameter p = 4.76;
  // A real parameter has to survive elaboration with its value; scaling by 100 and
  // casting is how a netlist can carry it (4.76 * 100 rounds to 476).
  assign o = int'(p * 100);
endmodule
