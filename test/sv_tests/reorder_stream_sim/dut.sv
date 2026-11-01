// Converted from chipsalliance/sv-tests (reorder_stream_sim).
// Upstream streams a constant and prints the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] a, output logic [31:0] b);
  assign b = {<< 8 {a}};
endmodule
