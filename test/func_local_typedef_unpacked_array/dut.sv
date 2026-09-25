// A constant function with a TYPEDEF'd unpacked-array local
// (`typedef int unsigned perm_t [W]; perm_t p;`).  The compile-time
// evaluator sized the local from its inner Variables()[0], which a
// typedef'd array does not have, so `p` was W bits with 1-bit elements:
// every `p[i] = ...` kept one bit and the packed result was 1 instead of
// 0x0E090403 (common_cells cc_sub_per_hash's get_permutations /
// get_xor_stages tables).  The element type is the array_typespec's
// Elem_typespec.
module func_local_typedef_unpacked_array #(
  parameter int unsigned W    = 4,
  parameter int unsigned Seed = 3
) (
  input  logic [31:0] data_i,
  output logic [31:0] perm_o
);
  typedef int unsigned perm_t [W];

  assign perm_o = pack_perm(Seed) ^ data_i;

  // p = 3, 4, 9, 14 -> 0x0E090403
  function automatic logic [31:0] pack_perm(input int unsigned seed);
    perm_t p;
    for (int unsigned i = 0; i < W; i++) p[i] = (i + seed) % W + 4 * i;
    return p[0] | (p[1] << 8) | (p[2] << 16) | (p[3] << 24);
  endfunction
endmodule
