// Converted from chipsalliance/sv-tests (22.5.1--define, :type: preprocessing).
// Upstream is the two `define directives ALONE, with no module: nothing about them is observable.
// The macro definition and the actual-argument spelling are kept VERBATIM --
// they are the construct under test; only the macro BODY changed, from a
// `$display` synthesis cannot see to an expression that drives a real output,
// so the text the preprocessor produced is what the proof reads.
// Upstream kept as orig.sv.
`define FOUR 5
`define SOMESTRING "somestring"
module top(input logic [7:0] a, output logic [8:0] o, output logic str_ok);
  assign o      = a + `FOUR;                        // `FOUR is 5
  assign str_ok = (`SOMESTRING == "somestring");    // and the string macro
endmodule
