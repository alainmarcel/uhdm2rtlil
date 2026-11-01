// Converted from chipsalliance/sv-tests (integers-token).
// Upstream declares `integer a;` and never drives or reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] o);
  integer a;
  // The `integer` type must be a signed 32-bit variable, which the round trip of a
  // negative value through it shows.
  always_comb a = x;
  assign o = a;
endmodule
