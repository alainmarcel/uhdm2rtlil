// Converted from chipsalliance/sv-tests (assign_in_expr_sim).
// Upstream runs the chain inside an `initial` block on constants, so none of the three variables is observable.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] a_o, output logic signed [31:0] b_o, output logic signed [31:0] c_o);
  always_comb begin
    int a; int b; int c;
    a = (b = (c = x));
    a_o = a;
    b_o = b;
    c_o = c;
  end
endmodule
