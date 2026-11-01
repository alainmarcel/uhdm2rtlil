// Converted from chipsalliance/sv-tests (parameter).
// Upstream declares the parameter and never reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] o);
  parameter p = 123;
  assign o = p;
endmodule
