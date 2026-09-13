// keccak_round with EnMasking=1 (Share=2): data_i[2] / state_o[2] flattened
// elem0@LSB.  Wrapper-only top (no RTL module of this name) — kmac_srcs.py
// seeds the closure from this file's references.
module keccak_round_m_flat import sha3_pkg::*; (
  input clk_i, input rst_ni,
  input valid_i, input [4:0] addr_i,
  input [2*64-1:0] data_i_flat, output ready_o, input run_i,
  input rand_valid_i, input rand_early_i, input [1600/2-1:0] rand_data_i, input rand_aux_i,
  output logic rand_update_o, output logic rand_consumed_o, output logic complete_o,
  output logic [2*1600-1:0] state_o_flat,
  input lc_ctrl_pkg::lc_tx_t lc_escalate_en_i,
  output logic sparse_fsm_error_o, output logic round_count_error_o, output logic rst_storage_error_o,
  input prim_mubi_pkg::mubi4_t clear_i
);
  logic [63:0] data_i [2]; logic [1599:0] state_o [2];
  for (genvar i = 0; i < 2; i++) begin : g
    assign data_i[i] = data_i_flat[i*64 +: 64];
    assign state_o_flat[i*1600 +: 1600] = state_o[i];
  end
  keccak_round #(.Width(1600), .DInWidth(64), .EnMasking(1'b1)) u (
    .clk_i, .rst_ni, .valid_i, .addr_i, .data_i(data_i), .ready_o, .run_i,
    .rand_valid_i, .rand_early_i, .rand_data_i, .rand_aux_i, .rand_update_o, .rand_consumed_o,
    .complete_o, .state_o(state_o), .lc_escalate_en_i, .sparse_fsm_error_o,
    .round_count_error_o, .rst_storage_error_o, .clear_i);
endmodule
