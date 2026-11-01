// Converted from chipsalliance/sv-tests (logic_vector).
// Upstream declares `logic [15:0] a;` and never drives or reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [15:0] x, output logic [15:0] a);
  assign a = x;
endmodule
