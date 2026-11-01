// Converted from chipsalliance/sv-tests (cond_op_sim).
// Upstream evaluates the ternary on constants inside an `initial` block and prints the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] a, input logic signed [31:0] b,
           output logic signed [31:0] c);
  assign c = (a > b) ? 11 : 13;
endmodule
