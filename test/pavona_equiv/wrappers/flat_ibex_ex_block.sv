// Flat-port shim (see flat_ibex_alu.sv): ibex_ex_block's imd_val ports are
// unpacked arrays ([33:0] x[2]); direct miters feed the same flat bits into
// opposite element orders between the frontends.  Explicit part-select
// mapping pins element 0 at the LSBs for both sides.
module ibex_ex_block_flat #(
  parameter ibex_pkg::rv32m_e RV32M           = ibex_pkg::RV32MFast,
  parameter ibex_pkg::rv32b_e RV32B           = ibex_pkg::RV32BNone,
  parameter bit               BranchTargetALU = 0
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  ibex_pkg::alu_op_e     alu_operator_i,
  input  logic [31:0]           alu_operand_a_i,
  input  logic [31:0]           alu_operand_b_i,
  input  logic                  alu_instr_first_cycle_i,

  input  logic [31:0]           bt_a_operand_i,
  input  logic [31:0]           bt_b_operand_i,

  input  ibex_pkg::md_op_e      multdiv_operator_i,
  input  logic                  mult_en_i,
  input  logic                  div_en_i,
  input  logic                  mult_sel_i,
  input  logic                  div_sel_i,
  input  logic  [1:0]           multdiv_signed_mode_i,
  input  logic [31:0]           multdiv_operand_a_i,
  input  logic [31:0]           multdiv_operand_b_i,
  input  logic                  multdiv_ready_id_i,
  input  logic                  data_ind_timing_i,

  output logic [1:0]            imd_val_we_o,
  output logic [67:0]           imd_val_d_flat_o,
  input  logic [67:0]           imd_val_q_flat_i,

  output logic [31:0]           alu_adder_result_ex_o,
  output logic [31:0]           result_ex_o,
  output logic [31:0]           branch_target_o,
  output logic                  branch_decision_o,

  output logic                  ex_valid_o
);
  logic [33:0] imd_val_q [2];
  logic [33:0] imd_val_d [2];

  assign imd_val_q[0] = imd_val_q_flat_i[33:0];
  assign imd_val_q[1] = imd_val_q_flat_i[67:34];
  assign imd_val_d_flat_o = {imd_val_d[1], imd_val_d[0]};

  ibex_ex_block #(
    .RV32M           (RV32M),
    .RV32B           (RV32B),
    .BranchTargetALU (BranchTargetALU)
  ) u_ex (
    .clk_i                   (clk_i),
    .rst_ni                  (rst_ni),
    .alu_operator_i          (alu_operator_i),
    .alu_operand_a_i         (alu_operand_a_i),
    .alu_operand_b_i         (alu_operand_b_i),
    .alu_instr_first_cycle_i (alu_instr_first_cycle_i),
    .bt_a_operand_i          (bt_a_operand_i),
    .bt_b_operand_i          (bt_b_operand_i),
    .multdiv_operator_i      (multdiv_operator_i),
    .mult_en_i               (mult_en_i),
    .div_en_i                (div_en_i),
    .mult_sel_i              (mult_sel_i),
    .div_sel_i               (div_sel_i),
    .multdiv_signed_mode_i   (multdiv_signed_mode_i),
    .multdiv_operand_a_i     (multdiv_operand_a_i),
    .multdiv_operand_b_i     (multdiv_operand_b_i),
    .multdiv_ready_id_i      (multdiv_ready_id_i),
    .data_ind_timing_i       (data_ind_timing_i),
    .imd_val_we_o            (imd_val_we_o),
    .imd_val_d_o             (imd_val_d),
    .imd_val_q_i             (imd_val_q),
    .alu_adder_result_ex_o   (alu_adder_result_ex_o),
    .result_ex_o             (result_ex_o),
    .branch_target_o         (branch_target_o),
    .branch_decision_o       (branch_decision_o),
    .ex_valid_o              (ex_valid_o)
  );
endmodule
