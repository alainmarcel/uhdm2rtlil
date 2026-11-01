// Converted from chipsalliance/sv-tests (bits_function).
// Upstream prints `$bits(val)` from an `initial` block, so the answer reaches nothing.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] x, output logic [31:0] val_o,
           output logic signed [31:0] nbits);
  logic [31:0] val;
  assign val   = x;
  assign val_o = val;
  assign nbits = $bits(val);
endmodule
