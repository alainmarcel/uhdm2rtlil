// Converted from chipsalliance/sv-tests (enum_numerical_expr).
// Upstream computes `val * 4` inside an `initial` block on a constant and drops it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [1:0] x, output logic signed [31:0] i);
  typedef enum {a, b, c, d} e;
  e val;
  // An enum used in arithmetic takes its ORDINAL value, so the multiply has to see
  // 0,1,2,3 -- which needs a real selector to tell from a constant fold.
  always_comb val = e'(x);
  assign i = val * 4;
endmodule
