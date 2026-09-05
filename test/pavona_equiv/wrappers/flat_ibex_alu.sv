// Flat-port shim for the equivalence miter.  ibex_alu's imd_val ports are
// unpacked arrays ([31:0] x[2]); when both frontends elaborate the module
// DIRECTLY, each flattens those ports to a 64-bit bus with the OPPOSITE
// element order (read_uhdm packs element 0 at the LSBs, read_slang at the
// MSBs), so the miter feeds the same flat bits into swapped elements and
// reports a counterexample that is purely the port convention (result_o =
// imd_val_q[0] | ... picked the other half).  Explicit part-select mapping
// here removes the ambiguity: both sides read this wrapper, the DUT
// connection is by name/index, and the flat bus order is pinned to
// element 0 at the LSBs.
module ibex_alu_flat #(
  parameter ibex_pkg::rv32b_e RV32B = ibex_pkg::RV32BNone
) (
  input  ibex_pkg::alu_op_e operator_i,
  input  logic [31:0]       operand_a_i,
  input  logic [31:0]       operand_b_i,

  input  logic              instr_first_cycle_i,

  input  logic [32:0]       multdiv_operand_a_i,
  input  logic [32:0]       multdiv_operand_b_i,

  input  logic              multdiv_sel_i,

  input  logic [63:0]       imd_val_q_flat_i,
  output logic [63:0]       imd_val_d_flat_o,
  output logic [1:0]        imd_val_we_o,

  output logic [31:0]       adder_result_o,
  output logic [33:0]       adder_result_ext_o,

  output logic [31:0]       result_o,
  output logic              comparison_result_o,
  output logic              is_equal_result_o
);
  logic [31:0] imd_val_q [2];
  logic [31:0] imd_val_d [2];

  assign imd_val_q[0] = imd_val_q_flat_i[31:0];
  assign imd_val_q[1] = imd_val_q_flat_i[63:32];
  assign imd_val_d_flat_o = {imd_val_d[1], imd_val_d[0]};

  ibex_alu #(.RV32B(RV32B)) u_alu (
    .operator_i          (operator_i),
    .operand_a_i         (operand_a_i),
    .operand_b_i         (operand_b_i),
    .instr_first_cycle_i (instr_first_cycle_i),
    .multdiv_operand_a_i (multdiv_operand_a_i),
    .multdiv_operand_b_i (multdiv_operand_b_i),
    .multdiv_sel_i       (multdiv_sel_i),
    .imd_val_q_i         (imd_val_q),
    .imd_val_d_o         (imd_val_d),
    .imd_val_we_o        (imd_val_we_o),
    .adder_result_o      (adder_result_o),
    .adder_result_ext_o  (adder_result_ext_o),
    .result_o            (result_o),
    .comparison_result_o (comparison_result_o),
    .is_equal_result_o   (is_equal_result_o)
  );
endmodule
