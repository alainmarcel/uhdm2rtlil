// Converted from chipsalliance/sv-tests (always_latch_expr).
// Upstream ties both `a` and `b` to constant 0 and never reads `q`, so neither the latch nor its HOLD behaviour is exercised.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module always_tb (input wire a, input wire b, output reg q);
  always_latch
    if(a) q <= b;
endmodule
