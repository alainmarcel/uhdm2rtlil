// Flat shim for tlul_socket_m1: flattens the unpacked-array-of-struct ports
// tl_h_i[M] / tl_h_o[M] to explicit elem0@LSB buses (element-order convention).
module tlul_socket_m1_flat import tlul_pkg::*; (
  input                     clk_i,
  input                     rst_ni,
  input  logic [4*$bits(tl_h2d_t)-1:0] tl_h_i_flat,
  output logic [4*$bits(tl_d2h_t)-1:0] tl_h_o_flat,
  output tl_h2d_t           tl_d_o,
  input  tl_d2h_t           tl_d_i
);
  tl_h2d_t tl_h_i [4];
  tl_d2h_t tl_h_o [4];
  for (genvar i = 0; i < 4; i++) begin : g
    assign tl_h_i[i] = tl_h_i_flat[i*$bits(tl_h2d_t) +: $bits(tl_h2d_t)];
    assign tl_h_o_flat[i*$bits(tl_d2h_t) +: $bits(tl_d2h_t)] = tl_h_o[i];
  end
  tlul_socket_m1 u (
    .clk_i, .rst_ni, .tl_h_i(tl_h_i), .tl_h_o(tl_h_o),
    .tl_d_o, .tl_d_i
  );
endmodule
