// Converted from chipsalliance/sv-tests (22.5.1--define_expansion_26, :type: preprocessing).
// Upstream prints the pasted identifier with `$display`, so nothing checks that `` actually pasted it.
// The macro definition and the actual-argument spelling are kept VERBATIM --
// they are the construct under test; only the macro BODY changed, from a
// `$display` synthesis cannot see to an expression that drives a real output,
// so the text the preprocessor produced is what the proof reads.
// Upstream kept as orig.sv.
`define append(f) f``_master
module top(input logic [7:0] a, output logic [7:0] o);
  logic [7:0] clock_master;
  // `` pastes the argument onto _master, so the macro must NAME the real signal
  // declared above -- a failed paste leaves it referring to something else.
  assign clock_master = a;
  assign o = `append(clock);
endmodule
