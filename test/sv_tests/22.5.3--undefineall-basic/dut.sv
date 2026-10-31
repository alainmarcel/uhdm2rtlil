// Converted from chipsalliance/sv-tests (22.5.3--undefineall-basic, :type: preprocessing).
// Upstream is `undefineall ALONE, with no module and nothing defined to undefine.
// The macro definition and the actual-argument spelling are kept VERBATIM --
// they are the construct under test; only the macro BODY changed, from a
// `$display` synthesis cannot see to an expression that drives a real output,
// so the text the preprocessor produced is what the proof reads.
// Upstream kept as orig.sv.
`define FOO 1
`undefineall
module top(input logic [7:0] a, input logic [7:0] b, output logic [8:0] o);
  // `undefineall must clear FOO, which `ifdef reads back.
`ifdef FOO
  assign o = a + b;
`else
  assign o = a - b;
`endif
endmodule
