// Converted from chipsalliance/sv-tests (22.5.1--define_expansion_24, :type: preprocessing).
// Upstream prints three strings with `$display`.  What it is really testing is that a macro name inside a STRING LITERAL is not expanded, and that a macro argument inside one is not substituted -- invisible to synthesis.
// The macro definition and the actual-argument spelling are kept VERBATIM --
// they are the construct under test; only the macro BODY changed, from a
// `$display` synthesis cannot see to an expression that drives a real output,
// so the text the preprocessor produced is what the proof reads.
// Upstream kept as orig.sv.
module top(output logic hi_in_string_ok, output logic arg_in_string_ok);
`define HI Hello
`define LO "`HI, world"
`define H(x) "Hello, x"
  // `HI inside `LO's body is NOT expanded, and `H's argument x inside the string
  // is NOT substituted, so each macro must equal the literal text spelled out here.
  assign hi_in_string_ok  = (`LO == "`HI, world");
  assign arg_in_string_ok = (`H(world) == "Hello, x");
endmodule
