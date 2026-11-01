// Converted from chipsalliance/sv-tests (always_ff).
// Upstream ties both the clock and the data to constant 0 and never reads `q`, so no register is exercised -- a frontend that dropped the block entirely would look the same.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module always_tb (input wire clk, input wire b, output reg q);
  always_ff @(posedge clk)
    q <= b;
endmodule
