// A parameter override whose actual is a localparam Surelog could not fold.
// `child` is parameterised with `.IdWidth($bits(id_t))` (an override actual
// Surelog leaves unfolded -- Surelog #4189), so its `HtCapacity` is inlined
// wherever it is used as the tree `((2**IdWidth <= Capacity) ? 2**IdWidth :
// Capacity)`, `$bits(id_t)` included; `leaf #(.W(HtCapacity))` receives that
// tree as its override RHS.  The paramod SIGNATURE builder and the module
// NAME builder both took the `operation` branch, which folded nothing and
// looked `id_t` up in the child: the signature was `leaf$W=` and the module
// was imported as plain `\leaf` at its DEFAULT width (1): "Resizing cell
// port u_leaf.a_i from 4 bits to 1 bits" (common_cells cc_id_queue's
// `cc_onehot_to_bin #(.OnehotWidth(HtCapacity))`).  Both builders now fold
// under force_const_fold with the override's names resolved in the
// instantiating scope, as the func-call branch already did.
//
// Two mids with different id_t widths give leaf W=4 and W=8; the type
// parameter is also a port of `mid` so the two mids are distinct modules by
// their existing port-width signature (that separate gap is
// type_param_signature's, not this fix's).  read_verilog cannot parse the
// type parameter, so the slang miter is the only real gate; it fails without
// the fix (y1_o computed at 1 bit).
module paramod_override_inlined_localparam (
  input  logic [7:0] a0_i, a1_i,
  output logic [7:0] y0_o, y1_o
);
  mid #(.id_t(logic [1:0])) u_m0 (.id_i(a0_i[1:0]), .a_i(a0_i), .y_o(y0_o));   // HtCapacity 4
  mid #(.id_t(logic [3:0])) u_m1 (.id_i(a1_i[3:0]), .a_i(a1_i), .y_o(y1_o));   // HtCapacity 8
endmodule

module leaf #(parameter int unsigned W = 1) (
  input  logic [W-1:0] a_i,
  output logic [W-1:0] y_o
);
  assign y_o = a_i + 1'b1;
endmodule

module child #(
  parameter int unsigned IdWidth  = 0,
  parameter int unsigned Capacity = 0
) (
  input  logic [7:0] a_i,
  output logic [7:0] y_o
);
  localparam int unsigned HtCapacity = (2**IdWidth <= Capacity) ? 2**IdWidth : Capacity;
  logic [HtCapacity-1:0] y;
  leaf #(.W(HtCapacity)) u_leaf (.a_i(a_i[HtCapacity-1:0]), .y_o(y));
  assign y_o = 8'(y);
endmodule

module mid #(parameter type id_t = logic) (
  input  id_t        id_i,
  input  logic [7:0] a_i,
  output logic [7:0] y_o
);
  child #(.IdWidth($bits(id_t)), .Capacity(8)) u_child (.*);
endmodule
