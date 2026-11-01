// Converted from chipsalliance/sv-tests (two_assignments_in_expression_sim).
// Upstream nests two compound assignments in one expression and prints the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, input logic signed [31:0] y,
           output logic signed [31:0] a_o, output logic signed [31:0] b_o,
           output logic signed [31:0] d_o);
  always_comb begin
    int a, b, d;
    a = x; b = y;
    d = ((b += (a+=1) + 1));
    a_o = a; b_o = b; d_o = d;
  end
endmodule
