// Converted from chipsalliance/sv-tests (22.5.2--undef-nonexisting, :type: preprocessing).
// Upstream is two `undef directives on names that were never defined, ALONE: the only claim is that this is accepted, and nothing checks it.
// The macro definition and the actual-argument spelling are kept VERBATIM --
// they are the construct under test; only the macro BODY changed, from a
// `$display` synthesis cannot see to an expression that drives a real output,
// so the text the preprocessor produced is what the proof reads.
// Upstream kept as orig.sv.
`undef FOO
`undef BAR
module top(input logic [7:0] a, input logic [7:0] b, output logic [8:0] o);
  // Undefining a name that was never defined must be accepted AND must leave both
  // names undefined, which `ifdef reads back.
`ifdef FOO
  assign o = 9'd0;
`elsif BAR
  assign o = 9'd1;
`else
  assign o = a - b;
`endif
endmodule
