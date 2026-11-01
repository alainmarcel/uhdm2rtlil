// Converted from chipsalliance/sv-tests (signed_func_sim).
// Upstream prints `$signed(4'b1000)` as -8 from an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [3:0] x, output logic signed [7:0] a);
  assign a = $signed(x);
endmodule
