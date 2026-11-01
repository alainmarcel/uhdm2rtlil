// Converted from chipsalliance/sv-tests (display_boh).
// Upstream's three radix displays are inside an `initial` block on a constant, so synthesis has no consumer for them and `opt` removes everything.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] x, output logic [31:0] o);
  // $displayb / $displayo / $displayh differ only in radix; each must become its own
  // $print cell, so a frontend that folded them together is visible as a count.
  always_comb begin
    $displayb(x);
    $displayo(x);
    $displayh(x);
  end
  assign o = x;
endmodule
