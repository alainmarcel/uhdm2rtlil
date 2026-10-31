// Converted from chipsalliance/sv-tests (22.5.3--undefineall-and-redefine, :type: preprocessing).
// Upstream is the define/undefineall/redefine sequence ALONE, with no module: neither the clearing nor the final redefinition is ever read back.
// The macro definition and the actual-argument spelling are kept VERBATIM --
// they are the construct under test; only the macro BODY changed, from a
// `$display` synthesis cannot see to an expression that drives a real output,
// so the text the preprocessor produced is what the proof reads.
// Upstream kept as orig.sv.
`define FOO "foo"
`undefineall
`define FOO 5
`undefineall
`define FOO(x,y) (x + y)
module top(input logic [7:0] a, input logic [7:0] b, output logic [8:0] o);
  // After two `undefineall sweeps FOO is the FUNCTION-LIKE macro defined last, so
  // expanding it with arguments must produce the sum -- neither the string nor the
  // 5 can still be in effect, or this would not compile.
  assign o = `FOO(a, b);
endmodule
