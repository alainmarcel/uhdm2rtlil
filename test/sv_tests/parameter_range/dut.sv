// Converted from chipsalliance/sv-tests (parameter_range).
// Upstream declares a sized-literal parameter and never reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic [15:0] o, output logic signed [31:0] nbits);
  parameter p = 16'h1234;
  // A sized literal gives the parameter its WIDTH as well as its value, which
  // $bits reads back.
  assign o     = p;
  assign nbits = $bits(p);
endmodule
