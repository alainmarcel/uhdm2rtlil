// aes_cipher_core with its default SecMasking=1 (NumShares=2) + SecSBoxImpl=SBoxImplDom.
// Multi-element unpacked-array ports flattened elem0@LSB (read_uhdm and read_slang
// flatten unpacked ports in opposite element order, so the miter/co-sim compare
// through this wrapper — same convention as the KMAC/EDN masked wrappers).
module aes_cipher_core_flat import aes_pkg::*; (
  input  logic clk_i,
  input  logic rst_ni,
  input  sp2v_e in_valid_i,
  output sp2v_e in_ready_o,
  output sp2v_e out_valid_o,
  input  sp2v_e out_ready_i,
  input  logic cfg_valid_i,
  input  ciph_op_e op_i,
  input  key_len_e key_len_i,
  input  sp2v_e crypt_i,
  output sp2v_e crypt_o,
  input  sp2v_e dec_key_gen_i,
  output sp2v_e dec_key_gen_o,
  input  logic prng_reseed_i,
  output logic prng_reseed_o,
  input  logic key_clear_i,
  output logic key_clear_o,
  input  logic data_out_clear_i,
  output logic data_out_clear_o,
  input  logic alert_fatal_i,
  output logic alert_o,
  input  logic [255:0] prd_clearing_state_i_flat,
  input  logic [511:0] prd_clearing_key_i_flat,
  input  logic force_masks_i,
  output logic        [3:0][3:0][7:0] data_in_mask_o,
  output logic entropy_req_o,
  input  logic entropy_ack_i,
  input  logic     [edn_pkg::ENDPOINT_BUS_WIDTH-1:0] entropy_i,
  input  logic [255:0] state_init_i_flat,
  input  logic [511:0] key_init_i_flat,
  output logic [255:0] state_o_flat
);
  logic [127:0] prd_clearing_state_i [2];
  assign prd_clearing_state_i[0] = prd_clearing_state_i_flat[127:0];
  assign prd_clearing_state_i[1] = prd_clearing_state_i_flat[255:128];
  logic [255:0] prd_clearing_key_i [2];
  assign prd_clearing_key_i[0] = prd_clearing_key_i_flat[255:0];
  assign prd_clearing_key_i[1] = prd_clearing_key_i_flat[511:256];
  logic [127:0] state_init_i [2];
  assign state_init_i[0] = state_init_i_flat[127:0];
  assign state_init_i[1] = state_init_i_flat[255:128];
  logic [255:0] key_init_i [2];
  assign key_init_i[0] = key_init_i_flat[255:0];
  assign key_init_i[1] = key_init_i_flat[511:256];
  logic [127:0] state_o [2];
  assign state_o_flat[127:0] = state_o[0];
  assign state_o_flat[255:128] = state_o[1];
  aes_cipher_core u (
    .clk_i, .rst_ni, .in_valid_i, .in_ready_o, .out_valid_o, .out_ready_i, .cfg_valid_i, .op_i, .key_len_i, .crypt_i, .crypt_o, .dec_key_gen_i, .dec_key_gen_o, .prng_reseed_i, .prng_reseed_o, .key_clear_i, .key_clear_o, .data_out_clear_i, .data_out_clear_o, .alert_fatal_i, .alert_o, .prd_clearing_state_i(prd_clearing_state_i), .prd_clearing_key_i(prd_clearing_key_i), .force_masks_i, .data_in_mask_o, .entropy_req_o, .entropy_ack_i, .entropy_i, .state_init_i(state_init_i), .key_init_i(key_init_i), .state_o(state_o)
  );
endmodule
