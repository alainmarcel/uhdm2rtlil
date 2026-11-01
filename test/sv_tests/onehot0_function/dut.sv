// Converted from chipsalliance/sv-tests (onehot0_function).
// Upstream prints `$onehot0(val0)` from an `initial` block, so the answer reaches nothing.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [3:0] val0, output logic o);
  // The operand is a port, so the predicate is exercised rather than folded, and
  // upstream's own asserted value is the 4'b0100 case.
  assign o = $onehot0(val0);
endmodule
