// Converted from chipsalliance/sv-tests (22.5.1--define_and_resetall, :type: preprocessing).
// Upstream checks with `$display` that `resetall does NOT clear a macro definition.
// The macro definition and the actual-argument spelling are kept VERBATIM --
// they are the construct under test; only the macro BODY changed, from a
// `$display` synthesis cannot see to an expression that drives a real output,
// so the text the preprocessor produced is what the proof reads.
// Upstream kept as orig.sv.
`define SOMESTRING "somestring"
`resetall
module top(input logic [7:0] a, output logic [8:0] o, output logic str_ok);
  // `resetall resets compiler directives, NOT macro definitions: the macro
  // defined above it must still expand here.
  assign str_ok = (`SOMESTRING == "somestring");
  assign o      = a + 9'd1;
endmodule
