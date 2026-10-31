// Converted from chipsalliance/sv-tests (22.5.1--define_expansion_19, :type: preprocessing).
// Upstream declares `logic [1:`wordsize] data` and never uses it, so the macro's value reaches nothing.
// The macro definition and the actual-argument spelling are kept VERBATIM --
// they are the construct under test; only the macro BODY changed, from a
// `$display` synthesis cannot see to an expression that drives a real output,
// so the text the preprocessor produced is what the proof reads.
// Upstream kept as orig.sv.
`define wordsize 8
module top(input logic [7:0] a, output logic [7:0] data, output logic [8:0] width);
  logic [1:`wordsize] w;
  // The macro sets the declared RANGE, so $bits reads the value it expanded to
  // and the assignment makes every bit of that range observable.
  assign w     = a;
  assign data  = w;
  assign width = $bits(w);
endmodule
