// Converted from chipsalliance/sv-tests (22.5.1--define_expansion_20, :type: preprocessing).
// Upstream instantiates two `nand` gates through the macro but leaves every terminal dangling, so neither gate drives anything.
// The macro definition and the actual-argument spelling are kept VERBATIM --
// they are the construct under test; only the macro BODY changed, from a
// `$display` synthesis cannot see to an expression that drives a real output,
// so the text the preprocessor produced is what the proof reads.
// Upstream kept as orig.sv.
`define var_nand(dly) nand #dly
module top(input logic n10, input logic n11, output logic q21, output logic q22);
  // The macro supplies the gate TYPE and its delay; the terminals are real ports,
  // so both instantiations have to produce a working nand.
  `var_nand(2) g121 (q21, n10, n11);
  `var_nand(5) g122 (q22, n10, n11);
endmodule
