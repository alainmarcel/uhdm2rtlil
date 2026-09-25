// An unpacked-array NET assigned as a whole (`assign Mask = get_mask(Seed)`)
// inside a child that a parent instantiates, with parameter overrides, from
// a generate block.  The parent's generate scope imports the child's
// DEFINITION; there the whole-assigned net was turned into a $mem, and the
// whole assign then pre-created a wire under the memory's name:
//   ERROR: Assert `count_id(wire->name) == 0' failed in kernel/rtlil.cc
// (common_cells cc_sub_per_hash's `assign Permutations = get_permutations()`
// under cc_hash_block's gen_hashes).  A whole-assigned net is a flat wire.
module bit_mask #(
  parameter int unsigned W    = 4,
  parameter int unsigned Seed = 3
) (
  input  logic [W-1:0] data_i,
  output logic [W-1:0] mask_o
);
  typedef logic mask_t [W];
  mask_t Mask;
  assign Mask = get_mask(Seed);

  for (genvar i = 0; i < W; i++) begin : gen_bit
    assign mask_o[i] = data_i[i] & Mask[i];
  end

  function automatic mask_t get_mask(input int unsigned seed);
    mask_t m;
    for (int unsigned i = 0; i < W; i++) m[i] = ((i + seed) % 3) != 0;
    return m;
  endfunction
endmodule

module net_whole_assign_genscope_inst (
  input  logic [7:0] data_i,
  output logic [7:0] mask_o,
  output logic [3:0] mask2_o
);
  // parameterized instances inside a generate: this is the path that
  // imports the child's definition and crashed
  for (genvar h = 0; h < 2; h++) begin : gen_h
    bit_mask #(.W(4), .Seed(h + 1)) i_m (
      .data_i(data_i[h*4 +: 4]), .mask_o(mask_o[h*4 +: 4]));
  end
  // and one with the default parameters
  bit_mask i_def (.data_i(data_i[3:0]), .mask_o(mask2_o));
endmodule
