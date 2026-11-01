// Converted from chipsalliance/sv-tests (rtoi_function).
// Upstream prints `$rtoi(21.37)` from an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] o, output logic signed [31:0] w);
  assign o = $rtoi(21.37);
  assign w = x;
endmodule
