// Flat shim for kmac_reduced (EnMasking=1 -> NumShares=2): flattens the
// 2-element unpacked-array ports msg_i[2] / state_o[2] to explicit elem0@LSB
// buses so read_uhdm and read_slang agree on element order (flattening-
// convention artifact, not a logic bug — same shim as tlul_socket_1n /
// kmac_reg_top).  All other ports pass straight through.
module kmac_reduced_flat
  import kmac_pkg::*;
  import sha3_pkg::*;
  import kmac_reg_pkg::*;
(
  input  logic clk_i,
  input  logic rst_ni,
  input  logic [2*128-1:0]      msg_i_flat,
  input  logic                  msg_valid_i,
  output logic                  msg_ready_o,
  input  logic                  start_i,
  input  logic                  process_i,
  input  logic                  run_i,
  input  prim_mubi_pkg::mubi4_t done_i,
  output prim_mubi_pkg::mubi4_t absorbed_o,
  output logic                  squeezing_o,
  output logic                  block_processed_o,
  output sha3_st_e              sha3_fsm_o,
  input  logic                  entropy_ready_i,
  input  logic                  entropy_refresh_req_i,
  input  logic [32-1:0]         entropy_i,
  output logic                  entropy_req_o,
  input  logic                  entropy_ack_i,
  input  sha3_mode_e            mode_i,
  input  keccak_strength_e      strength_i,
  input  logic [NSRegisterSize*8-1:0]   ns_prefix_i,
  input  logic [sha3_pkg::MsgStrbW-1:0] msg_strb_i,
  input  logic                  msg_mask_en_i,
  input  entropy_mode_e         entropy_mode_i,
  input  logic                  entropy_fast_process_i,
  input  logic                  entropy_in_keyblock_i,
  input  logic                  entropy_seed_update_i,
  input  logic [31:0]           entropy_seed_data_i,
  input  logic [TimerPrescalerW-1:0] wait_timer_prescaler_i,
  input  logic [EdnWaitTimerW-1:0]   wait_timer_limit_i,
  output logic [2*StateW-1:0]   state_o_flat,
  output logic                  state_valid_o,
  output prim_mubi_pkg::mubi4_t entropy_configured_o,
  input  logic [HashCntW-1:0]   entropy_hash_threshold_i,
  input  logic                  entropy_hash_clr_i,
  output logic [HashCntW-1:0]   entropy_hash_cnt_o,
  input  lc_ctrl_pkg::lc_tx_t   lc_escalate_en_i,
  output logic                  err_o,
  input  logic                  err_processed_i
);
  logic [128-1:0]    msg_i   [2];
  logic [StateW-1:0] state_o [2];
  for (genvar i = 0; i < 2; i++) begin : g
    assign msg_i[i] = msg_i_flat[i*128 +: 128];
    assign state_o_flat[i*StateW +: StateW] = state_o[i];
  end
  kmac_reduced u (
    .clk_i, .rst_ni, .msg_i(msg_i), .msg_valid_i, .msg_ready_o, .start_i, .process_i, .run_i,
    .done_i, .absorbed_o, .squeezing_o, .block_processed_o, .sha3_fsm_o,
    .entropy_ready_i, .entropy_refresh_req_i, .entropy_i, .entropy_req_o, .entropy_ack_i,
    .mode_i, .strength_i, .ns_prefix_i, .msg_strb_i, .msg_mask_en_i, .entropy_mode_i,
    .entropy_fast_process_i, .entropy_in_keyblock_i, .entropy_seed_update_i,
    .entropy_seed_data_i, .wait_timer_prescaler_i, .wait_timer_limit_i,
    .state_o(state_o), .state_valid_o, .entropy_configured_o,
    .entropy_hash_threshold_i, .entropy_hash_clr_i, .entropy_hash_cnt_o,
    .lc_escalate_en_i, .err_o, .err_processed_i
  );
endmodule
