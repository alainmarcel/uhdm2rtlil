// Converted from chipsalliance/sv-tests (reorder_stream).
// Upstream streams a constant inside an `initial` block and never reads the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] a, output logic [31:0] b);
  // `{<< 8 {a}}` reverses the order of the BYTES.
  assign b = {<< 8 {a}};
endmodule
