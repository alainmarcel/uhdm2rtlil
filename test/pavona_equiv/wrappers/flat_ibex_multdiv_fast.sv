// Flat-port shim (see flat_ibex_alu.sv): the imd_val ports are unpacked
// arrays; direct miters feed the same flat bits into opposite element
// orders between the frontends.  Part-select mapping pins element 0 at the
// LSBs for both sides.
module ibex_multdiv_fast_flat #(
  parameter ibex_pkg::rv32m_e RV32M = ibex_pkg::RV32MFast
) (
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic             mult_en_i,
  input  logic             div_en_i,
  input  logic             mult_sel_i,
  input  logic             div_sel_i,
  input  ibex_pkg::md_op_e operator_i,
  input  logic  [1:0]      signed_mode_i,
  input  logic [31:0]      op_a_i,
  input  logic [31:0]      op_b_i,
  input  logic [33:0]      alu_adder_ext_i,
  input  logic [31:0]      alu_adder_i,
  input  logic             equal_to_zero_i,
  input  logic             data_ind_timing_i,

  output logic [32:0]      alu_operand_a_o,
  output logic [32:0]      alu_operand_b_o,

  input  logic [67:0]      imd_val_q_flat_i,
  output logic [67:0]      imd_val_d_flat_o,
  output logic  [1:0]      imd_val_we_o,

  input  logic             multdiv_ready_id_i,

  output logic [31:0]      multdiv_result_o,
  output logic             valid_o
);
  logic [33:0] imd_val_q [2];
  logic [33:0] imd_val_d [2];
  assign imd_val_q[0] = imd_val_q_flat_i[33:0];
  assign imd_val_q[1] = imd_val_q_flat_i[67:34];
  assign imd_val_d_flat_o = {imd_val_d[1], imd_val_d[0]};

  ibex_multdiv_fast #(.RV32M(RV32M)) u_md (
    .clk_i              (clk_i),
    .rst_ni             (rst_ni),
    .mult_en_i          (mult_en_i),
    .div_en_i           (div_en_i),
    .mult_sel_i         (mult_sel_i),
    .div_sel_i          (div_sel_i),
    .operator_i         (operator_i),
    .signed_mode_i      (signed_mode_i),
    .op_a_i             (op_a_i),
    .op_b_i             (op_b_i),
    .alu_adder_ext_i    (alu_adder_ext_i),
    .alu_adder_i        (alu_adder_i),
    .equal_to_zero_i    (equal_to_zero_i),
    .data_ind_timing_i  (data_ind_timing_i),
    .alu_operand_a_o    (alu_operand_a_o),
    .alu_operand_b_o    (alu_operand_b_o),
    .imd_val_q_i        (imd_val_q),
    .imd_val_d_o        (imd_val_d),
    .imd_val_we_o       (imd_val_we_o),
    .multdiv_ready_id_i (multdiv_ready_id_i),
    .multdiv_result_o   (multdiv_result_o),
    .valid_o            (valid_o)
  );
endmodule
