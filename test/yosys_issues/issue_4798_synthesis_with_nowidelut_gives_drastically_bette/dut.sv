// YosysHQ/yosys#4798 (open): Synthesis with -nowidelut gives drastically better results
// https://github.com/YosysHQ/yosys/issues/4798
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module sha3theta (
  input  wire[4:0][4:0][63:0] i_state,
  output wire[4:0][4:0][63:0] o_state
);

  wire[4:0][63:0] sum_sheet;

  genvar i;
  generate
  for (i = 0; i < 5; i++) begin
    assign sum_sheet[i] =
      i_state[0][i] ^
      i_state[1][i] ^
      i_state[2][i] ^
      i_state[3][i] ^
      i_state[4][i];
  end
  endgenerate

  genvar row, col;
  generate
  for (row = 0; row < 5; row++) begin
    for (col = 0; col < 5; col++) begin
      assign o_state[row][col] =
        i_state[row][col] ^
        sum_sheet[(col - 1) % 5] ^
        {sum_sheet[(col + 1) % 5][62:0], sum_sheet[(col + 1) % 5][63:63]};
    end
  end
  endgenerate;

endmodule

