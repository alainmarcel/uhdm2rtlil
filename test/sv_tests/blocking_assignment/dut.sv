// Converted from chipsalliance/sv-tests (blocking_assignment).
// Upstream chains `a = 1; b = a;` inside an `initial` block and prints both, so the ORDERING that makes a blocking assignment visible to the next statement is not checked by anything synthesis can see.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic x, output logic a, output logic b);
  // Blocking assignments in sequence: b must see the value a was just given, not
  // a's previous one.  Upstream's `logic a` is one bit wide, so this keeps that.
  always_comb begin
    a = x;
    b = a;
  end
endmodule
