// Converted from chipsalliance/sv-tests (union_test_0).
// Upstream forward-declares a union typedef, completes it, and leaves the module EMPTY.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
typedef union myunion_fwd;
typedef union { logic a; logic b; } myunion_fwd;
module test(input logic x, output logic a_o, output logic b_o, output logic signed [31:0] nbits);
  myunion_fwd u;
  always_comb u.a = x;
  assign a_o = u.a; assign b_o = u.b;
  assign nbits = $bits(myunion_fwd);
endmodule
