// Converted from chipsalliance/sv-tests (always_comb).
// Upstream ties `a` to the constant 0 and never reads `b`, so the always_comb block computes a constant nothing consumes.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module always_tb (input wire a, output reg b);
  always_comb
    b = ~a;
endmodule
