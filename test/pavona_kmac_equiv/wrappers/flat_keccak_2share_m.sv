// keccak_2share with EnMasking=1 (Share=2): s_i[2] / s_o[2] flattened elem0@LSB.
module keccak_2share_m_flat import sha3_pkg::*; (
  input clk_i, input rst_ni,
  input lc_ctrl_pkg::lc_tx_t lc_escalate_en_i,
  input [4:0] rnd_i, input prim_mubi_pkg::mubi4_t phase_sel_i,
  input dom_out_low_i, input dom_in_low_i, input dom_in_rand_ext_i, input dom_update_i,
  input [1600/2-1:0] rand_i,
  input [2*1600-1:0] s_i_flat, output logic [2*1600-1:0] s_o_flat
);
  logic [1599:0] s_i [2]; logic [1599:0] s_o [2];
  for (genvar i = 0; i < 2; i++) begin : g
    assign s_i[i] = s_i_flat[i*1600 +: 1600];
    assign s_o_flat[i*1600 +: 1600] = s_o[i];
  end
  keccak_2share #(.Width(1600), .EnMasking(1'b1)) u (
    .clk_i, .rst_ni, .lc_escalate_en_i, .rnd_i, .phase_sel_i, .dom_out_low_i, .dom_in_low_i,
    .dom_in_rand_ext_i, .dom_update_i, .rand_i, .s_i(s_i), .s_o(s_o));
endmodule
