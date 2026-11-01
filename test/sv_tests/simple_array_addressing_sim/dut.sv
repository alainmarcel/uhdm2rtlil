// Converted from chipsalliance/sv-tests (simple_array_addressing_sim).
// Upstream already has ports but reads a memory that is NEVER WRITTEN, so the output is x on every address.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input clk, input we, input [7:0] wa, input [7:0] wd, input [7:0] a,
           output [7:0] b);
  reg [7:0] mem [0:255];
  // A write port is added so the array is a real memory with real contents.
  always @(posedge clk) if (we) mem[wa] <= wd;
  assign b = mem[a];
endmodule
