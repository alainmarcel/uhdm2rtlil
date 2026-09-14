// A multi-dimensional typedef declared INSIDE a generate block and used by a
// function of that block (prim_lfsr's gen_out_non_linear: `typedef logic
// [NumSboxes-1:0][LfsrIdxDw-1:0] matrix_col_t` + lrotcol/revcol).
// get_width_from_typespec trusted ExprEval for the 2-range logic_typespec, and
// ExprEval cannot see the generate-scope localparam NumSboxes: it silently
// dropped that dimension (size 6 instead of 96), so every function local of
// the type held one entry and the S-box input index tables were garbage.
module genscope_func_typedef_multirange #(parameter int LfsrDw = 64) (
  output logic [LfsrDw-1:0][$clog2(LfsrDw)-1:0] idx_o
);
  localparam int unsigned LfsrIdxDw = $clog2(LfsrDw);
  if (1) begin : gen_out_non_linear
    localparam int NumSboxes = LfsrDw / 4;
    logic [3:0][NumSboxes-1:0][LfsrIdxDw-1:0] matrix_indices;
    for (genvar j = 0; j < LfsrDw; j++) begin : gen_input_idx_map
      assign matrix_indices[j / NumSboxes][j % NumSboxes] = j;
    end
    logic [3:0][NumSboxes-1:0][LfsrIdxDw-1:0] matrix_rotrev_indices;
    typedef logic [NumSboxes-1:0][LfsrIdxDw-1:0] matrix_col_t;
    function automatic matrix_col_t lrotcol(matrix_col_t col, integer shift);
      matrix_col_t out;
      for (int k = 0; k < NumSboxes; k++) begin
        out[(k + shift) % NumSboxes] = col[k];
      end
      return out;
    endfunction : lrotcol
    always_comb begin : p_rotrev
      matrix_rotrev_indices[0] = matrix_indices[0];
      matrix_rotrev_indices[1] = lrotcol(matrix_indices[1], NumSboxes/2);
      matrix_rotrev_indices[2] = lrotcol(matrix_indices[2], 1);
      matrix_rotrev_indices[3] = lrotcol(matrix_indices[3], 3);
    end
    for (genvar k = 0; k < LfsrDw; k++) begin : gen_reverse_upper
      assign idx_o[k] = matrix_rotrev_indices[k % 4][k / 4];
    end
  end
endmodule
