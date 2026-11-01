// Converted from chipsalliance/sv-tests (signed_func).
// Upstream applies `$signed` to a constant inside an `initial` block and never reads the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [3:0] x, output logic signed [7:0] a);
  // $signed reinterprets the operand, so a 4-bit value with its MSB set must
  // SIGN-extend into the wider signed target.
  assign a = $signed(x);
endmodule
