// Converted from chipsalliance/sv-tests (event_control_edge).
// Upstream ties the clock to the constant 0 and never reads `a`, so the ANY-edge sensitivity (`@(edge clk)`) is never exercised.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module block_tb (input wire clk, output reg [3:0] a);
  always @(edge clk) a <= ~a;
endmodule
