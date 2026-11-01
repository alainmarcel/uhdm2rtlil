// Converted from chipsalliance/sv-tests (assign_in_exp).
// Upstream runs `-=` inside an expression inside an `initial` block and prints the result, so neither the value the expression produced nor the variable's new value is observable.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] a_o,
           output logic signed [31:0] b_o);
  always_comb begin
    int a;
    int b;
    a = x;
    b = (a-=1);
    a_o = a;
    b_o = b;
  end
endmodule
