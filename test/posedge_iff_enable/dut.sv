// IEEE 1800-2017 9.4.2.3: `@(posedge clk iff en)` triggers only when the
// qualifier holds at the edge -- a clock enable.  read_uhdm found no clock in
// the qualified event and stopped ("Clock signal is empty when creating sync
// rule"; chipsalliance/sv-tests 9.4.2.3--event_conditional).
module dut (
    input  logic       clk,
    input  logic       en,
    input  logic       rst_n,
    input  logic [7:0] a,
    output logic [7:0] y,
    output logic [7:0] cnt
);
  always @(posedge clk iff en == 1)
    y <= a;

  // the qualifier may be any expression, and the body any statement
  always @(posedge clk iff (en && rst_n))
    if (a[0]) cnt <= cnt + 1;
    else      cnt <= 8'd0;
endmodule
