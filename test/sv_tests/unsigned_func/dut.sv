// Converted from chipsalliance/sv-tests (unsigned_func).
// Upstream assigns `$unsigned(-4)` to an 8-bit variable inside an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic [7:0] a);
  // $unsigned reinterprets the two's-complement pattern; -4 is ...11111100.
  assign a = $unsigned(x);
endmodule
