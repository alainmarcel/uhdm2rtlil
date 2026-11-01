// Converted from chipsalliance/sv-tests (22.5.1--define_expansion_13, :type: preprocessing).
// Upstream prints the arguments with `$display`, so which value each macro
// parameter took is invisible to synthesis.  The macro's parameter list and the
// ACTUAL ARGUMENT SPELLING are kept VERBATIM -- they are the construct under test;
// only the body changed, to a named parameter override, which is the one
// synthesizable position where an argument that substitutes to NOTHING is still
// legal (`.R()` takes the default).  Upstream kept as orig.sv.
`define MACRO2(a=5, b, c="C") arg_sink #(.P(a), .Q(b), .R(c)) u_m (.po(po), .qo(qo), .ro(ro));
module top(output logic [31:0] po, output logic [31:0] qo,
           output logic [31:0] ro);
`MACRO2 (1, , 3)
endmodule
module arg_sink #(parameter P = 101, parameter Q = 102, parameter R = 103)
                 (output logic [31:0] po, output logic [31:0] qo,
                  output logic [31:0] ro);
  // Each macro argument reaches its OWN output, so a wrong substitution names
  // the argument instead of just moving a sum.  The defaults are what an EMPTY
  // actual must fall back to: `.R()` is the one synthesizable place where both
  // a value and nothing are legal.
  assign po = P;
  assign qo = Q;
  assign ro = R;
endmodule
