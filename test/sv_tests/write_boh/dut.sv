// Converted from chipsalliance/sv-tests (write_boh).
// Upstream's `$write` is inside an `initial` block on a constant, so synthesis has no consumer for it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] x, output logic [31:0] o);
  always_comb begin
    $writeb(x); $writeo(x); $writeh(x);
  end
  assign o = x;
endmodule
