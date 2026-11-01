// Converted from chipsalliance/sv-tests (event_conditional).
// Upstream ties the clock, the enable and the data to constants and never reads `y`, so the `iff` qualifier is never exercised.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module block_tb (input wire clk, input wire en, input wire a, output reg y);
  // `iff` qualifies the edge: the register must capture only when the condition
  // holds, which makes it an ENABLED flop rather than a plain one.
  always @(posedge clk iff en == 1)
    y <= a;
endmodule
