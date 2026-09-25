// A TYPEDEF'd 2-D unpacked array read per element with two genvar indices:
//   typedef int unsigned perm_t [R][W];  perm_t Perm;  ... data_i[Perm[r][i]]
// The var_select path derives the outer stride and the inner dimensions
// from the array_var's own Ranges() and the element type from its inner
// Variables()[0].  A typedef'd array has neither — both live on its
// array_typespec — so `Perm[r][i]` found no element and every read came
// back EMPTY ("vpiVarSelect: element 'Perm[0]' not found", empty RHS in
// the continuous assign): common_cells cc_sub_per_hash's permutation and
// xor tables, hash_o undriven.  Rows are palindromes so the test does not
// depend on the nested-pattern row order (#896); the rows differ so the
// outer index is exercised.
module typedef_2d_unpacked_elem_select #(
  parameter int unsigned W = 4,
  parameter int unsigned R = 2
) (
  input  logic [W-1:0] data_i,
  output logic [W-1:0] hash_o
);
  typedef int unsigned perm_t [R][W];
  perm_t Perm;
  assign Perm = '{'{1, 2, 2, 1}, '{0, 3, 3, 0}};

  logic [R-1:0][W-1:0] permuted;
  for (genvar r = 0; r < R; r++) begin : gen_round
    for (genvar i = 0; i < W; i++) begin : gen_bit
      if (r == 0) begin : gen_input
        assign permuted[r][i] = data_i[Perm[r][i]];
      end else begin : gen_perm
        assign permuted[r][i] = permuted[r-1][Perm[r][i]];
      end
    end
  end
  assign hash_o = permuted[R-1];
endmodule
