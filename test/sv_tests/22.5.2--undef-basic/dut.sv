// Converted from chipsalliance/sv-tests (22.5.2--undef-basic, :type: preprocessing).
// Upstream is `define then `undef ALONE, with no module: whether the `undef took effect is never looked at.
// The macro definition and the actual-argument spelling are kept VERBATIM --
// they are the construct under test; only the macro BODY changed, from a
// `$display` synthesis cannot see to an expression that drives a real output,
// so the text the preprocessor produced is what the proof reads.
// Upstream kept as orig.sv.
`define FOO "foo"
`undef FOO
module top(input logic [7:0] a, input logic [7:0] b, output logic [8:0] o);
  // `ifdef makes the `undef observable: if it did not take effect the WRONG arm
  // compiles and the subtraction below is never proven.
`ifdef FOO
  assign o = a + b;
`else
  assign o = a - b;
`endif
endmodule
