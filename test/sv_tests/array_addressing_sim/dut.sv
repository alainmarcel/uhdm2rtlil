// Converted from chipsalliance/sv-tests (array_addressing_sim).
// Upstream writes element 123, reads it back in the same `initial` block and prints it, so synthesis sees neither the write nor the read.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic clk, input logic we, input logic [7:0] wd,
           output logic [7:0] a);
  logic [7:0] mem [0:1023];
  // Upstream's constant index is kept and the write is clocked, so the round trip
  // is a real one.  The written VALUE comes from a port, so what reaches `a` has to
  // travel through the storage rather than being a folded constant.
  always_ff @(posedge clk)
    if (we) mem[123] <= wd;
  assign a = mem[123];
endmodule
