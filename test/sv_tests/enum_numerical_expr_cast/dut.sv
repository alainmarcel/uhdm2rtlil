// Converted from chipsalliance/sv-tests (enum_numerical_expr_cast).
// Upstream computes `e'(val+1)` inside an `initial` block on a constant and drops it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [1:0] x, output logic [1:0] o);
  typedef enum {a, b, c, d} e;
  e val;
  always_comb begin
    val = e'(x);
    val = e'(val+1);   // the cast back to the enum type, kept verbatim
  end
  assign o = val;
endmodule
