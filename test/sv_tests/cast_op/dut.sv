// Converted from chipsalliance/sv-tests (cast_op).
// Upstream casts a real expression to `int` in a declaration initialiser and never reads the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] o);
  int a = int'(2.1 * 3.7);
  // 2.1 * 3.7 is 7.77, and a cast to int ROUNDS rather than truncating: 8, not 7.
  assign o = a;
endmodule
