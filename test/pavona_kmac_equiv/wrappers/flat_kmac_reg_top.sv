// Flat shim for kmac_reg_top: flattens the unpacked-array-of-struct window
// ports tl_win_o[2] / tl_win_i[2] to explicit elem0@LSB buses so read_uhdm and
// read_slang agree on element order (pure flattening-convention artifact, not
// a logic bug — same shim as pavona_tlul_equiv's tlul_socket_1n).
module kmac_reg_top_flat import tlul_pkg::*; (
  input clk_i,
  input rst_ni,
  input rst_shadowed_ni,
  input  tl_h2d_t tl_i,
  output tl_d2h_t tl_o,
  output logic [2*$bits(tl_h2d_t)-1:0] tl_win_o_flat,
  input  logic [2*$bits(tl_d2h_t)-1:0] tl_win_i_flat,
  output kmac_reg_pkg::kmac_reg2hw_t reg2hw,
  input  kmac_reg_pkg::kmac_hw2reg_t hw2reg,
  output logic shadowed_storage_err_o,
  output logic shadowed_update_err_o,
  output logic intg_err_o
);
  tl_h2d_t tl_win_o [2];
  tl_d2h_t tl_win_i [2];
  for (genvar i = 0; i < 2; i++) begin : g
    assign tl_win_o_flat[i*$bits(tl_h2d_t) +: $bits(tl_h2d_t)] = tl_win_o[i];
    assign tl_win_i[i] = tl_win_i_flat[i*$bits(tl_d2h_t) +: $bits(tl_d2h_t)];
  end
  kmac_reg_top u (
    .clk_i, .rst_ni, .rst_shadowed_ni, .tl_i, .tl_o,
    .tl_win_o(tl_win_o), .tl_win_i(tl_win_i),
    .reg2hw, .hw2reg, .shadowed_storage_err_o, .shadowed_update_err_o, .intg_err_o
  );
endmodule
