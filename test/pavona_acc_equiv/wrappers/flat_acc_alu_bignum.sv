// acc_alu_bignum (AccPQCEn=1) with its two multi-element unpacked output ports
// ([Share]) flattened elem0@LSB: read_uhdm and read_slang flatten unpacked
// ports in opposite element order, so the miter compares through this wrapper.
module acc_alu_bignum_flat
  import acc_pkg::*;
(
  input logic clk_i,
  input logic rst_ni,

  input  alu_bignum_operation_t operation_i,
  input  logic                  operation_valid_i,
  input  logic                  operation_commit_i, // used for SVAs only
  output logic [WLEN-1:0]       operation_result_o,
  output logic                  selection_flag_o,

  input  alu_predec_bignum_t  alu_predec_bignum_i,
  input  ispr_predec_bignum_t ispr_predec_bignum_i,

  input  ispr_e                       ispr_addr_i,
  input  logic [31:0]                 ispr_base_wdata_i,
  input  logic [BaseWordsPerWLEN-1:0] ispr_base_wr_en_i,
  input  logic [ExtWLEN-1:0]          ispr_bignum_wdata_intg_i,
  input  logic                        ispr_bignum_wr_en_i,
  input  logic [NFlagGroups-1:0]      ispr_flags_wr_i,
  input  logic                        ispr_wr_commit_i,
  input  logic                        ispr_init_i,
  output logic [ExtWLEN-1:0]          ispr_rdata_intg_o,
  input  logic                        ispr_rd_en_i,

  input  logic [ExtWLEN-1:0]          ispr_acc_intg_i,
  output logic [ExtWLEN-1:0]          ispr_acc_wr_data_intg_o,
  output logic                        ispr_acc_wr_en_o,

  input  logic [ExtWLEN-1:0]          ispr_acch_intg_i,
  output logic [ExtWLEN-1:0]          ispr_acch_wr_data_intg_o,
  output logic                        ispr_acch_wr_en_o,

  output logic                        reg_intg_violation_err_o,

  input  logic                        sec_wipe_mod_urnd_i,
  input  logic                        sec_wipe_kmac_regs_urnd_i,

  input  logic                        sec_wipe_running_i,
  output logic                        sec_wipe_err_o,

  input  flags_t                      mac_operation_flags_i,
  input  flags_t                      mac_operation_flags_en_i,

  input  logic [WLEN-1:0]             rnd_data_i,
  input  logic [WLEN-1:0]             urnd_data_i,

  input  logic [1:0][SideloadKeyWidth-1:0] sideload_key_shares_i,

  output logic alu_predec_error_o,
  output logic ispr_predec_error_o,
  output logic kmac_intf_fatal_error_o,
  output logic kmac_intf_recov_error_o,

  output logic [1:0] kmac_msg_write_ready_o_flat,
  output logic [1:0] kmac_msg_pending_write_o_flat,
  output logic kmac_digest_valid_o,

  output kmac_pkg::app_req_t          kmac_app_req_o,
  input  kmac_pkg::app_rsp_t          kmac_app_rsp_i
);
  logic kmac_msg_write_ready_o   [2];
  logic kmac_msg_pending_write_o [2];
  acc_alu_bignum u_dut (.*);
  assign kmac_msg_write_ready_o_flat   = {kmac_msg_write_ready_o[1], kmac_msg_write_ready_o[0]};
  assign kmac_msg_pending_write_o_flat = {kmac_msg_pending_write_o[1], kmac_msg_pending_write_o[0]};
endmodule
