// Converted from sv-tests chapter-22/22.10--celldefine-basic-2.sv
// (:type: preprocessing).  Upstream is a bare `celldefine with no
// `endcelldefine and no module.  The unterminated directive is kept and now
// precedes real logic, so its effect on compilation is observable.
`celldefine
module top(input logic [7:0] a, output logic [7:0] inv);
  assign inv = ~a;
endmodule
