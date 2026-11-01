// Converted from chipsalliance/sv-tests (display_task).
// Upstream's `$display` is inside an `initial` block on a constant, so synthesis has no consumer for it and `opt` removes everything.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] x, output logic [31:0] o);
  // A $display in a combinational block becomes a $print cell, which is what gives
  // the logic feeding it a consumer; without one, opt removes it all.
  always_comb
    $display(x);
  assign o = x;
endmodule
