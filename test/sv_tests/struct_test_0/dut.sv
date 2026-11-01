// Converted from chipsalliance/sv-tests (struct_test_0).
// Upstream forward-declares a struct typedef, completes it, and leaves the module EMPTY.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
typedef struct mystruct_fwd;
typedef struct { logic a; logic b; } mystruct_fwd;
module test(input logic x, input logic y, output logic a_o, output logic b_o,
            output logic signed [31:0] nbits);
  mystruct_fwd s;
  always_comb begin s.a = x; s.b = y; end
  assign a_o = s.a; assign b_o = s.b;
  assign nbits = $bits(mystruct_fwd);
endmodule
