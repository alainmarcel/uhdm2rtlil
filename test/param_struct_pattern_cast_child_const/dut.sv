// A child parameter set from a SIZE-CAST of a localparam STRUCT pattern built
// from the module's own (overridden) parameters (OpenTitan lc_ctrl:
// `localparam lc_hw_rev_t HwRev = '{silicon_creator_id: SiliconCreatorId,
// product_id: ProductId, revision_id: RevisionId, reserved: '0};
// prim_const #(.ConstVal(HwRevWidth'(HwRev)))`).  In the Egret top the child
// constant came out 0 (hw_rev_o) while read_slang had the configured IDs.
package param_struct_pattern_cast_child_const_pkg;
  typedef struct packed {
    logic [15:0] creator;
    logic [15:0] product;
    logic [7:0]  revision;
    logic [23:0] reserved;
  } hw_rev_t;
endpackage

module param_struct_pattern_cast_child_const_k #(parameter int Width = 1,
                                                 parameter logic [Width-1:0] ConstVal = '0) (
  output logic [Width-1:0] out_o
);
  // Per-bit generate, as OpenTitan's prim_generic prim_const: the branch
  // Surelog elaborates for each bit IS the constant.
  for (genvar i = 0; i < Width; i++) begin : gen_bits
    if (ConstVal[i]) begin : gen_hi
      assign out_o[i] = 1'b1;
    end else begin : gen_lo
      assign out_o[i] = 1'b0;
    end
  end
endmodule

module param_struct_pattern_cast_child_const_ip
  import param_struct_pattern_cast_child_const_pkg::*;
#(
  parameter logic [15:0] CreatorId = '0,
  parameter logic [15:0] ProductId = '0,
  parameter logic [7:0]  RevisionId = '0
) (
  output hw_rev_t hw_rev_o
);
  localparam int HwRevWidth = $bits(hw_rev_t);
  localparam hw_rev_t HwRev = '{creator:  CreatorId,
                                product:  ProductId,
                                revision: RevisionId,
                                reserved: '0};
  logic [HwRevWidth-1:0] raw;
  param_struct_pattern_cast_child_const_k #(
    .Width(HwRevWidth),
    .ConstVal(HwRevWidth'(HwRev))
  ) u_const (
    .out_o(raw)
  );
  assign hw_rev_o = hw_rev_t'(raw);
endmodule

module param_struct_pattern_cast_child_const
  import param_struct_pattern_cast_child_const_pkg::*;
(
  output hw_rev_t hw_rev_o,
  output hw_rev_t hw_rev_dflt_o
);
  localparam logic [15:0] TopCreator = 16'h4001;
  param_struct_pattern_cast_child_const_ip #(
    .CreatorId(TopCreator), .ProductId(16'h0002), .RevisionId(8'h01)
  ) u_ip (.hw_rev_o);
  param_struct_pattern_cast_child_const_ip u_ip_dflt (.hw_rev_o(hw_rev_dflt_o));
endmodule
