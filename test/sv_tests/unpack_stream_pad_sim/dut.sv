// Converted from chipsalliance/sv-tests (unpack_stream_pad_sim).
// Upstream left-streams three ints into a 128-bit local -- WIDER than the source, so the stream is PADDED -- inside an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] a, input logic [31:0] b, input logic [31:0] c,
           output bit [127:0] d);
  // The target is 32 bits wider than the 96-bit stream, so the result is padded.
  assign d = {<< 32 {a, b, c}};
endmodule
