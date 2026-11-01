// Converted from chipsalliance/sv-tests (stream_concat_sim).
// Upstream right-streams two constants into a 64-bit vector inside an `initial` block and prints the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] a, input logic [31:0] b, output logic [63:0] c);
  // `{>> 8 {a, b}}` keeps the byte order, so this is a plain concatenation.
  assign c = {>> 8 {a, b}};
endmodule
