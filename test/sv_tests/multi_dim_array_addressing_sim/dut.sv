// Converted from chipsalliance/sv-tests (multi_dim_array_addressing_sim).
// Upstream writes one constant index pair inside an `initial` block, reads it back and prints it, so synthesis sees neither.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic clk, input logic we, input logic [7:0] wd,
           output logic [7:0] a);
  logic [7:0] mem [0:1023][0:3];
  // Upstream's constant index pair is kept and the write is clocked; the value
  // comes from a port so a folded constant cannot satisfy the shape below.
  always_ff @(posedge clk)
    if (we) mem[123][2] <= wd;
  assign a = mem[123][2];
endmodule
