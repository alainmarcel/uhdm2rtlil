// Flat shim for spi_host_reg_top: flattens the unpacked-array-of-struct window
// ports tl_win_o[2] / tl_win_i[2] to explicit elem0@LSB buses (read_uhdm
// flattens unpacked PORTS elem0@LSB, read_slang elem0@MSB — the raw miter
// compared swapped windows and reported a spurious cex).  Wrapper-only top.
module spi_host_reg_top_flat import tlul_pkg::*; (
  input  logic clk_i,
  input  logic rst_ni,
  input  tl_h2d_t tl_i,
  output tl_d2h_t tl_o,
  output logic [2*$bits(tl_h2d_t)-1:0] tl_win_o_flat,
  input  logic [2*$bits(tl_d2h_t)-1:0] tl_win_i_flat,
  output spi_host_reg_pkg::spi_host_reg2hw_t reg2hw,
  input  spi_host_reg_pkg::spi_host_hw2reg_t hw2reg,
  input  top_racl_pkg::racl_policy_vec_t racl_policies_i,
  output top_racl_pkg::racl_error_log_t  racl_error_o,
  output logic intg_err_o
);
  tl_h2d_t tl_win_o [2];
  tl_d2h_t tl_win_i [2];
  for (genvar i = 0; i < 2; i++) begin : g
    assign tl_win_o_flat[i*$bits(tl_h2d_t) +: $bits(tl_h2d_t)] = tl_win_o[i];
    assign tl_win_i[i] = tl_win_i_flat[i*$bits(tl_d2h_t) +: $bits(tl_d2h_t)];
  end
  spi_host_reg_top u (
    .clk_i, .rst_ni, .tl_i, .tl_o, .tl_win_o, .tl_win_i, .reg2hw, .hw2reg,
    .racl_policies_i, .racl_error_o, .intg_err_o);
endmodule
