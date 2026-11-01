// Converted from chipsalliance/sv-tests (event_control_negedge).
// Upstream ties the clock to the constant 0 and never reads `a`, so a falling-edge sensitivity is never exercised -- a frontend that dropped the block entirely would look identical.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module block_tb (input wire clk, output reg [3:0] a);
  // Upstream toggles `a` on every edge; the clock is a port now so the block is a
  // real register.
  always @(negedge clk) a <= ~a;
endmodule
