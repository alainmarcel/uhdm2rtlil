// A constant function with a 2-D unpacked local (`int unsigned p [R][W]`)
// written and read per element with two indices.  The compile-time
// evaluator flattens a function-local array to one Const and modelled it
// as ONE-dimensional: `p[r][i]` was taken as "element r, BIT i", so the
// table writes landed on single bits of the first R elements and the
// reads returned single bits (common_cells cc_sub_per_hash's
// get_permutations / get_xor_stages).  The unpacked dims are now
// recorded per local and a full index list addresses element
// (r-lo_r)*W + (i-lo_i).
module func_local_2d_unpacked_array #(
  parameter int unsigned W    = 4,
  parameter int unsigned R    = 2,
  parameter int unsigned Seed = 3
) (
  input  logic [31:0] data_i,
  output logic [31:0] perm_o
);
  assign perm_o = pack_perm(Seed) ^ data_i;

  // p[r][i] = (i+seed+r)%W + 16r + 4i ; packed picks = 0x1A150E03
  function automatic logic [31:0] pack_perm(input int unsigned seed);
    int unsigned p [R][W];
    for (int unsigned r = 0; r < R; r++)
      for (int unsigned i = 0; i < W; i++)
        p[r][i] = (i + seed + r) % W + 16 * r + 4 * i;
    return p[0][0] | (p[0][3] << 8) | (p[1][1] << 16) | (p[1][2] << 24);
  endfunction
endmodule
