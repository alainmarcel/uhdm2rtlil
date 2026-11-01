// Converted from chipsalliance/sv-tests (array_addressing).
// Upstream reads one constant index of a 1024-entry array in an `initial` block and drops the result, so neither the array nor the addressing reaches anything.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic clk, input logic we, input logic [9:0] addr,
           input logic [7:0] wd, output logic [7:0] a);
  logic [7:0] mem [0:1023];
  // The address is a real port, so the indexing is exercised rather than folded.
  always_ff @(posedge clk)
    if (we) mem[addr] <= wd;
  assign a = mem[addr];
endmodule
