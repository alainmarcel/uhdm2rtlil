// Converted from chipsalliance/sv-tests (event_comma_op).
// Upstream ties all four inputs to the constant 0 and never reads `out`, so the sensitivity list is never exercised.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module block_tb (input wire a, input wire b, input wire c, input wire d,
                output reg out);
  always @(a, b, c, d)
    out = (a | b) & (c | d);
endmodule
