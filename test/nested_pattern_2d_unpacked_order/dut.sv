// A NESTED assignment pattern into a 2-D unpacked array:
//   int unsigned Perm [R][W];  assign Perm = '{'{3,0,1,2}, '{1,2,3,0}};
// The flat-net convention is element 0 at the LSBs for every unpacked
// dimension, and every element read (`Perm[r][i]`) assumes it.  The
// pattern fold looked for the target's unpacked dimension on the op's
// PARENT assignment — but an inner '{...} is the operand of the OUTER
// pattern op, so it found none and folded its row first-at-MSB: every
// row was read reversed (common_cells cc_sub_per_hash's per-round
// permutation tables, hash bits taken from the wrong inputs).  Rows
// differ so a reversed row is visible on hash_o.
module nested_pattern_2d_unpacked_order #(
  parameter int unsigned W = 4,
  parameter int unsigned R = 2
) (
  input  logic [W-1:0] data_i,
  output logic [W-1:0] hash_o
);
  int unsigned Perm [R][W];
  assign Perm = '{'{3, 0, 1, 2}, '{1, 2, 3, 0}};

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
