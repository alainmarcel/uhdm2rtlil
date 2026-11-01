// Converted from chipsalliance/sv-tests (pragma-directive, :type: preprocessing).
// Upstream wraps a never-used wire in a `pragma protect ... `pragma protect end
// region inside an otherwise empty module.  The region is kept VERBATIM and now
// guards real logic: if the pragma pair perturbed compilation the proven
// adder/subtractor inside it would not survive.  Upstream kept as orig.sv.
module top(input logic [7:0] a, input logic [7:0] b, input logic sel,
           output logic [8:0] y);
`pragma protect
  wire [8:0] protected_wire;
  assign protected_wire = sel ? (a + b) : (a - b);
`pragma protect end
  assign y = protected_wire;
endmodule
