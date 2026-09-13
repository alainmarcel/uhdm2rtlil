// prim_sha2 with MultimodeEn=1 (as instantiated by prim_sha2_32 inside hmac).
module prim_sha2_mm_flat import prim_sha2_pkg::*; (
  input clk_i, input rst_ni,
  input wipe_secret_i, input sha_word32_t wipe_v_i,
  input fifo_rvalid_i, input sha_fifo64_t fifo_rdata_i, output logic fifo_rready_o,
  input sha_en_i, input hash_start_i, input hash_stop_i, input hash_continue_i,
  input digest_mode_e digest_mode_i, input hash_process_i, output logic hash_done_o,
  input [63:0] message_length_i, input sha_word64_t [7:0] digest_i, input logic [7:0] digest_we_i,
  output sha_word64_t [7:0] digest_o, output logic digest_on_blk_o, output sha_st_e sha_st_o,
  output logic hash_running_o, output logic idle_o
);
  prim_sha2 #(.MultimodeEn(1)) u (.*);
endmodule
