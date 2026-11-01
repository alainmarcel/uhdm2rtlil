// Converted from chipsalliance/sv-tests (23.2--module-label, :type: parsing).
// Upstream is an EMPTY `module top (); endmodule`, so there is nothing to observe.
// The module header and its ending are kept in upstream's spelling and the module
// now has real ports and real logic.
// Upstream kept as orig.sv.
module top(input logic [7:0] a, input logic [7:0] b, input logic sel,
           output logic [8:0] y);
  assign y = sel ? (a + b) : (a - b);
endmodule : top
