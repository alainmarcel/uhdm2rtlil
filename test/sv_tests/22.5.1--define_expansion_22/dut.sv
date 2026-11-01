// Converted from chipsalliance/sv-tests (22.5.1--define_expansion_22, :type: preprocessing).
// Upstream is the `max macro definition ALONE, with no module: it is never expanded.
// The macro definition and the actual-argument spelling are kept VERBATIM --
// they are the construct under test; only the macro BODY changed, from a
// `$display` synthesis cannot see to an expression that drives a real output,
// so the text the preprocessor produced is what the proof reads.
// Upstream kept as orig.sv.
`define max(a,b)((a) > (b) ? (a) : (b))
module top(input logic [7:0] x, input logic [7:0] y, output logic [7:0] o);
  assign o = `max(x,y);
endmodule
