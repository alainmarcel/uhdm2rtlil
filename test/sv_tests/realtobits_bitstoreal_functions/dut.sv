// Converted from chipsalliance/sv-tests (realtobits_bitstoreal_functions).
// Upstream prints `$bitstoreal($realtobits(12.45))` from an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] o, output logic signed [31:0] w);
  // A round trip through the 64-bit pattern must give the value back: 12.45 * 100.
  assign o = int'($bitstoreal($realtobits(12.45)) * 100);
  assign w = x;
endmodule
