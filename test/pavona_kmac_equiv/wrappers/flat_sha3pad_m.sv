// sha3pad with EnMasking=1 (Share=2): msg_data_i[2] / keccak_data_o[2] flattened elem0@LSB.
module sha3pad_m_flat import sha3_pkg::*; (
  input clk_i, input rst_ni,
  input msg_valid_i, input [2*MsgWidth-1:0] msg_data_i_flat, input [MsgStrbW-1:0] msg_strb_i,
  output logic msg_ready_o, input [NSRegisterSize*8-1:0] ns_data_i,
  output logic keccak_valid_o, output logic [KeccakMsgAddrW-1:0] keccak_addr_o,
  output logic [2*MsgWidth-1:0] keccak_data_o_flat, input logic keccak_ready_i,
  output logic keccak_run_o, input keccak_complete_i,
  input sha3_mode_e mode_i, input keccak_strength_e strength_i,
  input start_i, input process_i, input prim_mubi_pkg::mubi4_t done_i,
  output prim_mubi_pkg::mubi4_t absorbed_o, input lc_ctrl_pkg::lc_tx_t lc_escalate_en_i,
  output logic sparse_fsm_error_o, output logic msg_count_error_o
);
  logic [MsgWidth-1:0] msg_data_i [2]; logic [MsgWidth-1:0] keccak_data_o [2];
  for (genvar i = 0; i < 2; i++) begin : g
    assign msg_data_i[i] = msg_data_i_flat[i*MsgWidth +: MsgWidth];
    assign keccak_data_o_flat[i*MsgWidth +: MsgWidth] = keccak_data_o[i];
  end
  sha3pad #(.EnMasking(1'b1)) u (
    .clk_i, .rst_ni, .msg_valid_i, .msg_data_i(msg_data_i), .msg_strb_i, .msg_ready_o, .ns_data_i,
    .keccak_valid_o, .keccak_addr_o, .keccak_data_o(keccak_data_o), .keccak_ready_i, .keccak_run_o,
    .keccak_complete_i, .mode_i, .strength_i, .start_i, .process_i, .done_i, .absorbed_o,
    .lc_escalate_en_i, .sparse_fsm_error_o, .msg_count_error_o);
endmodule
