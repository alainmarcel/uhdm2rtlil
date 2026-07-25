// Minimal repro: `2 ** genvar` index arithmetic in a generate loop must
// const-fold, not emit a $pow cell (as lzc.sv does across CVA6).
module genvar_pow_index #(
    parameter int unsigned WIDTH = 8
) (
    input  logic [WIDTH-1:0] in_i,
    output logic [WIDTH-1:0] out_o
);
  localparam int unsigned NumLevels = $clog2(WIDTH);
  logic [2**NumLevels-1:0] nodes;

  for (genvar level = 0; unsigned'(level) < NumLevels; level++) begin : g_lvl
    for (genvar k = 0; k < 2 ** level; k++) begin : g_k
      if (level == NumLevels - 1) begin
        assign nodes[2 ** level - 1 + k] = in_i[k * 2] | in_i[k * 2 + 1];
      end else begin
        assign nodes[2 ** level - 1 + k] =
            nodes[2 ** (level + 1) - 1 + k * 2] | nodes[2 ** (level + 1) - 1 + k * 2 + 1];
      end
    end
  end

  assign out_o = nodes[WIDTH-1:0];
endmodule
