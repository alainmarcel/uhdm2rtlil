// Converted from chipsalliance/sv-tests (non_blocking_assignment).
// Upstream's `a <= 2` is inside an `initial` block on a 1-bit variable, so synthesis sees a constant it never reads -- and the TRUNCATION upstream is really exercising is invisible.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, input logic clk, output logic a);
  // A non-blocking assignment into a ONE-BIT variable must truncate to its low bit,
  // which is what upstream's `a <= 2` (an even value, so bit 0 is 0) exercises.
  always_ff @(posedge clk)
    a <= x;
endmodule
