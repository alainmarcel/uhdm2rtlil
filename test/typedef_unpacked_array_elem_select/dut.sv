// A TYPEDEF'd unpacked array (`typedef int unsigned perm_t [W]; perm_t Perm;`)
// assigned as a whole and read per element with a genvar index.  The
// array_var carries no Ranges() of its own and no inner Variables(): both
// the unpacked dimension and the element type live on its array_typespec.
// The bit-select geometry lookup only read the var's own Ranges(), so the
// element width stayed 1 and `Perm[i]` read BIT i of the 128-bit flat wire
// instead of the 32-bit element (common_cells cc_sub_per_hash's
// permutation tables: every hash bit selected the wrong input bit).
module typedef_unpacked_array_elem_select #(
  parameter int unsigned W    = 4,
  parameter int unsigned Seed = 3
) (
  input  logic [W-1:0] data_i,
  output logic [W-1:0] hash_o
);
  typedef int unsigned perm_t [W];
  perm_t Perm;
  // elements 3,0,1,2: element i must select data_i[Perm[i]]
  assign Perm = '{(Seed % W), ((Seed + 1) % W), ((Seed + 2) % W), ((Seed + 3) % W)};

  for (genvar i = 0; i < W; i++) begin : gen_bit
    assign hash_o[i] = data_i[Perm[i]];
  end
endmodule
