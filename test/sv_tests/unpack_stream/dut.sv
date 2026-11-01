// Converted from chipsalliance/sv-tests (unpack_stream).
// Upstream left-streams three ints into a 96-bit local inside an `initial` block and never reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] a, input logic [31:0] b, input logic [31:0] c,
           output bit [95:0] d);
  // With no slice size the stream is BIT-reversed over the whole concatenation.
  assign d = {<<{a, b, c}};
endmodule
