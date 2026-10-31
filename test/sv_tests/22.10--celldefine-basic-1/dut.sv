// Converted from sv-tests chapter-22/22.10--celldefine-basic-1.sv
// (:type: preprocessing).  Upstream is ONLY the two directives and contains no
// module, so nothing about it is observable.  The directives are kept and now
// bracket real logic: if `celldefine`/`endcelldefine` perturbed compilation the
// adder would not survive, so the construct's effect IS observable.
`celldefine
module top(input logic [7:0] a, input logic [7:0] b, output logic [8:0] sum);
  assign sum = a + b;
endmodule
`endcelldefine
