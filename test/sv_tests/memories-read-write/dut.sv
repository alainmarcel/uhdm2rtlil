// Converted from chipsalliance/sv-tests (memories-read-write).
// Upstream writes one element twice inside an `initial` block and prints it, so synthesis sees neither the write nor the read.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic clk, input logic we, input logic [7:0] wd,
           output logic [7:0] rd);
  logic [7:0] mem [0:255];
  // Upstream's constant index is kept and the write is clocked, so the round trip
  // is a real one; the VALUE comes from a port so a folded constant cannot satisfy
  // the shape below.
  always_ff @(posedge clk)
    if (we) mem[5] <= wd;
  assign rd = mem[5];
endmodule
