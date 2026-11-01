// Converted from chipsalliance/sv-tests (nonescaped-access).
// Upstream reads an ESCAPED name (`\\cpu3 `) through its NON-escaped spelling (`cpu3`) under `default_nettype none`, and never reads the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
`default_nettype none
module identifiers(input wire x, output wire reference_test);
  reg \cpu3 ;
  // The escaped declaration and the plain reference must name the SAME signal --
  // and under `default_nettype none` a mismatch cannot silently become an implicit
  // net, it is an error.
  always @(*)
    \cpu3  = x;
  assign reference_test = cpu3;
endmodule
