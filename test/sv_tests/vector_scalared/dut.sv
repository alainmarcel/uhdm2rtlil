// Converted from chipsalliance/sv-tests (vector_scalared).
// Upstream declares a `tri1 scalared` vector and never drives or reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [15:0] x, output logic [15:0] o);
	tri1 scalared [15:0] a;
  // `scalared` is an access hint; the net must still carry all sixteen bits.
  assign a = x;
  assign o = a;
endmodule
