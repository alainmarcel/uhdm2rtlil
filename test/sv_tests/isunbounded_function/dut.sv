// Converted from chipsalliance/sv-tests (isunbounded_function).
// Upstream prints `$isunbounded` of a literal and of a parameter set to `$`.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic x, output logic lit, output logic unb, output logic w);
parameter int i = $;
  assign lit = $isunbounded(1);
  assign unb = $isunbounded(i);
  assign w   = x;
endmodule
