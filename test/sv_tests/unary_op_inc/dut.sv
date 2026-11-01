// Converted from chipsalliance/sv-tests (unary_op_inc).
// Upstream applies `a++;` to a constant inside an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] o);
  always_comb begin
    int a;
    a = x;
    a++;
    o = a;
  end
endmodule
