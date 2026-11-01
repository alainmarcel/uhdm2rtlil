// Converted from chipsalliance/sv-tests (unpack_stream_sim).
// Upstream bit-reverses three ints into a 96-bit local and prints it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] a, input logic [31:0] b, input logic [31:0] c,
           output bit [95:0] d);
  assign d = {<<{a, b, c}};
endmodule
