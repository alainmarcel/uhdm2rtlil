// `automatic` block-locals declared inside SIBLING branches of one always_comb.
//
// All four declarations of `size_mask`/`conv_ratio` are promoted onto ONE
// module-level wire (the promotion epoch is per-PROCESS, so the recursion that
// visits every nested block reuses it).  That wire was then seeded with a HOLD
// of itself (`$0\size_mask = \size_mask`), which makes it look assigned only
// under each arm's condition -- so `proc` inferred a LATCH for it, where
// read_slang infers none and keeps a pure combinational temporary.
//
// An `automatic` has no previous value: it is re-created on every evaluation
// of the block, and reading one before assignment is undefined in SV.  Seeding
// with X removes the latch.
//
// THIS IS A STRUCTURAL TEST.  The latch is functionally harmless here -- each
// arm assigns before it reads, so the SAT miter against read_slang passes
// either way (it did, before the fix).  Only the netlist SHAPE catches it, so
// the gate is test_structural.ys, not the miter.
//
// Reduced from PULP axi_dw_downsizer, which has four sibling
// `automatic addr_t size_mask/conv_ratio/align_adj` declarations in its read
// always_comb and emitted 10 latches against read_slang's 0.
module automatic_local_case_arm_latch (
  input  logic [7:0] len_i,
  input  logic [2:0] size_i,
  input  logic [1:0] burst_i,
  output logic [7:0] out_o
);
  always_comb begin
    out_o = '0;
    case (burst_i)
      2'b01: begin
        automatic logic [31:0] size_mask;
        automatic logic [31:0] conv_ratio;
        size_mask  = (1 << size_i) - 1;
        conv_ratio = ((1 << size_i) + 8 - 1) / 8;
        out_o = (len_i + 1) * conv_ratio[7:0] - size_mask[7:0] - 1;
      end
      2'b10: begin
        automatic logic [31:0] size_mask;
        automatic logic [31:0] conv_ratio;
        size_mask  = (1 << size_i) - 1;
        conv_ratio = ((1 << size_i) + 8 - 1) / 8;
        out_o = conv_ratio[7:0] - size_mask[7:0];
      end
      default: ;
    endcase
  end
endmodule
