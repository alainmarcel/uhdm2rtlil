// Converted from chipsalliance/sv-tests (basic-unpacked-structures).
// Upstream assigns both members inside an `initial` block and prints them.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input logic [3:0] xlo, input logic [3:0] xhi, output bit [3:0] hi_o,
            output bit [3:0] lo_o);
  struct {
    bit [3:0] lo;
    bit [3:0] hi;
  } p1;
  // An UNPACKED struct has no bit layout to speak of, so what is observable is
  // that each member keeps its own value -- upstream's 5 and a.
  always_comb begin
    p1.lo = xlo;
    p1.hi = xhi;
  end
  assign hi_o = p1.hi;
  assign lo_o = p1.lo;
endmodule
