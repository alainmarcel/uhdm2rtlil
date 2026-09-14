// prim_lfsr's gen_out_non_linear index tables: functions declared INSIDE a
// generate block, one of them streaming with a PARAMETER-named slice size
// (`{<<LfsrIdxDw{col}}`).  Surelog parsed that slice size as a simple_type and
// compiled it as $bits(<non-type>) = 0 (a full bit reversal instead of 6-bit
// slices), and inside a generate block the parameter is not in the generate
// scope's own parameter map (chipsalliance/Surelog#4173).  Needs Surelog at or
// past that fix; rows 2 and 3 of rr_o must be element-reversed columns.
module genscope_func_stream_slice_param #(parameter int LfsrDw = 64) (
  output logic [LfsrDw-1:0][$clog2(LfsrDw)-1:0] idx_o,
  output logic [3:0][LfsrDw/4-1:0][$clog2(LfsrDw)-1:0] rr_o
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
  function automatic matrix_col_t revcol(matrix_col_t col);
    return {<<LfsrIdxDw{col}};
  endfunction : revcol
  always_comb begin : p_rotrev
    matrix_rotrev_indices[0] = matrix_indices[0];
    matrix_rotrev_indices[1] = lrotcol(matrix_indices[1], NumSboxes/2);
    matrix_rotrev_indices[2] = revcol(matrix_indices[2]);
    matrix_rotrev_indices[3] = revcol(lrotcol(matrix_indices[3], 1));
  end
  logic [LfsrDw-1:0][LfsrIdxDw-1:0] sbox_in_indices;
  for (genvar k = 0; k < LfsrDw; k++) begin : gen_reverse_upper
    assign sbox_in_indices[k] = matrix_rotrev_indices[k % 4][k / 4];
  end
  assign idx_o = sbox_in_indices;
  assign rr_o = matrix_rotrev_indices;
  end
endmodule
