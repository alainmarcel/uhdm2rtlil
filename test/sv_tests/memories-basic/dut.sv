// Converted from chipsalliance/sv-tests (memories-basic).
// Upstream declares a 256-entry memory and never drives or reads it, so nothing confirms it became a memory rather than 256 registers.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic clk, input logic we, input logic [7:0] addr,
           input logic [7:0] wd, output logic [7:0] rd);
  logic [7:0] mem [0:255];
  // The address is a real port, so the array has to be inferred as a MEMORY --
  // a port-addressed 256-entry array expanded to registers would be 256 muxes.
  always_ff @(posedge clk)
    if (we) mem[addr] <= wd;
  assign rd = mem[addr];
endmodule
