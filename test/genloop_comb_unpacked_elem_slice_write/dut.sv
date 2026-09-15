// Per-word slice writes into ONE element of a module-level unpacked array
// from always_comb blocks inside a generate loop (OpenTitan-family ACC
// acc_alu_bignum `kmac_msg_intg_d[0][i_word*39+:39] = ...`, Share = 2).
module genloop_comb_unpacked_elem_slice_write #(
  parameter int Share = 2,
  parameter int Words = 3
) (
  input  logic                clk_i,
  input  logic                rst_ni,
  input  logic [Words-1:0]    wr_en0_i,
  input  logic [Words-1:0]    wr_en1_i,
  input  logic [Words*8-1:0]  wdata_i,
  output logic [Words*8-1:0]  q0_o,
  output logic [Words*8-1:0]  q1_o
);
  logic [Words*8-1:0] d [Share];
  logic [Words*8-1:0] q [Share];

  for (genvar w = 0; w < Words; w++) begin : g_word0
    always_comb begin
      d[0][w*8+:8] = q[0][w*8+:8];
      if (wr_en0_i[w]) begin
        d[0][w*8+:8] = wdata_i[w*8+:8];
      end
    end
  end

  for (genvar w = 0; w < Words; w++) begin : g_word1
    always_comb begin
      d[1][w*8+:8] = '0;
      if (wr_en1_i[w]) begin
        d[1][w*8+:8] = ~wdata_i[w*8+:8];
      end
    end
  end

  for (genvar s = 0; s < Share; s++) begin : g_reg
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) q[s] <= '0;
      else         q[s] <= d[s];
    end
  end

  assign q0_o = q[0];
  assign q1_o = q[1];
endmodule
