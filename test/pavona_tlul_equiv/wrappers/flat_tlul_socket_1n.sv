// Flat shim for tlul_socket_1n: flattens the unpacked-array-of-struct ports
// tl_d_o[N] / tl_d_i[N] to explicit elem0@LSB buses so read_uhdm and read_slang
// agree on element order (pure flattening-convention artifact, not a logic bug).
module tlul_socket_1n_flat import tlul_pkg::*; (
  input                     clk_i,
  input                     rst_ni,
  input  tl_h2d_t           tl_h_i,
  output tl_d2h_t           tl_h_o,
  output logic [4*$bits(tl_h2d_t)-1:0] tl_d_o_flat,
  input  logic [4*$bits(tl_d2h_t)-1:0] tl_d_i_flat,
  input  [2:0]              dev_select_i
);
  tl_h2d_t tl_d_o [4];
  tl_d2h_t tl_d_i [4];
  for (genvar i = 0; i < 4; i++) begin : g
    assign tl_d_o_flat[i*$bits(tl_h2d_t) +: $bits(tl_h2d_t)] = tl_d_o[i];
    assign tl_d_i[i] = tl_d_i_flat[i*$bits(tl_d2h_t) +: $bits(tl_d2h_t)];
  end
  tlul_socket_1n u (
    .clk_i, .rst_ni, .tl_h_i, .tl_h_o,
    .tl_d_o(tl_d_o), .tl_d_i(tl_d_i), .dev_select_i
  );
endmodule
