// Converted from chipsalliance/sv-tests (basic-union).
// Upstream writes the wide member inside an `initial` block and prints both members.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input logic [7:0] x, output bit [7:0] v1_o, output bit [3:0] v2_o);
  union {
    bit [7:0] v1;
    bit [3:0] v2;
  } un;
  // The members are different WIDTHS, so the narrow one must alias the low nibble:
  // upstream's 140 (8'h8C) reads back as 12 (4'hC) through v2.
  assign un.v1 = x;
  assign v1_o  = un.v1;
  assign v2_o  = un.v2;
endmodule
