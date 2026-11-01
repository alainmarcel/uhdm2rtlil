// Converted from chipsalliance/sv-tests (basic-packed-unions).
// Upstream writes one member inside an `initial` block and prints both.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input logic [7:0] x, output bit [7:0] v1_o, output bit [7:0] v2_o);
  union packed {
    bit [7:0] v1;
    bit [7:0] v2;
  } un;
  // Writing one member of a union must be readable through the OTHER: that is the
  // whole claim, and upstream's 140 shows up on both.
  assign un.v1 = x;
  assign v1_o  = un.v1;
  assign v2_o  = un.v2;
endmodule
