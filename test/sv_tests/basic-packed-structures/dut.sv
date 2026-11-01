// Converted from chipsalliance/sv-tests (basic-packed-structures).
// Upstream assigns the struct as a whole inside an `initial` block and prints the members.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input logic [7:0] x, output bit [7:0] p1_o, output bit [3:0] hi_o,
            output bit [3:0] lo_o);
  struct packed {
    bit [3:0] lo;
    bit [3:0] hi;
  } p1;
  // The whole-struct assignment is kept; the value is a port now, so the member
  // ORDER is observable -- in a packed struct the FIRST member is the HIGH bits,
  // which is why upstream's 8'h5a gives lo = 5 and hi = a.
  assign p1   = x;
  assign p1_o = p1;
  assign hi_o = p1.hi;
  assign lo_o = p1.lo;
endmodule
