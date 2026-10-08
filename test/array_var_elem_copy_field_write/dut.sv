// An unpacked array of structs whose element type has an ENUM member is a
// VARIABLE to Surelog (array_var over a struct_var), not an array_net over a
// struct_net like an all-logic struct.  The `arr[idx].field = rhs` write
// helper found no element struct typespec on it and declined, so the write
// fell through to the hier_path READ path -- whose LHS is the element's
// IN-FLIGHT value.  Right after `predec_mod[cycle] = predec_mul[cycle % 3]`
// that value is the SOURCE element, so the field write landed in predec_mul:
// every iteration polluted its source, later iterations copied the polluted
// source, and `check` reported two drivers per bit (OTBN otbn_mac_bignum_fsm,
// 18 conflicts; the same shape without the enum member reads clean).
module array_var_elem_copy_field_write
  (input  logic [1:0] off_i,
   input  logic       is_mod_i,
   input  logic [3:0] cur_i,
   output logic [1:0] oa_o,
   output logic       en_o,
   output logic       mul2_o);
  typedef enum logic [1:0] {MulOpA, MulOpMu, MulOpq} mul_op_e;
  typedef struct packed {
    logic [1:0] op_a_qw_sel;
    mul_op_e    mul_op_b_sel;
    logic       mul_add_en;
  } predec_t;
  localparam predec_t PredecDefault = '0;
  localparam int unsigned NMul = 3;
  localparam int unsigned NMod = 16;   // 2**$bits(cur_i): every cur_i is in range (an out-of-range read is X, not a comparison)
  localparam int unsigned NVec = 4;
  predec_t    predec_mul [NMul];
  predec_t    predec_mod [NMod];
  predec_t    predec_vec [NVec];
  logic [1:0] elem_idx_mod [NMod];
  always_comb begin
    predec_mul = '{default: PredecDefault};
    predec_mul[2].mul_add_en = 1'b1;
    for (int unsigned cycle = 0; cycle < NMod; cycle++) begin
      elem_idx_mod[cycle] = 2'(cycle / NMul) + off_i;
      predec_mod[cycle]            = predec_mul[cycle % NMul];
      predec_mod[cycle].mul_add_en = elem_idx_mod[cycle][0];
    end
  end
  always_comb begin
    predec_vec = '{default: PredecDefault};
    for (int unsigned cycle = 0; cycle < NVec; cycle++)
      predec_vec[cycle].op_a_qw_sel = 2'(cycle);
  end
  predec_t predec_multi [2][NMod];
  always_comb begin
    predec_multi[0] = '{default: PredecDefault};
    for (int unsigned cycle = 0; cycle < NVec; cycle++)
      predec_multi[0][cycle] = predec_vec[cycle];
    predec_multi[1] = '{default: PredecDefault};
    for (int unsigned cycle = 0; cycle < NMod; cycle++)
      predec_multi[1][cycle] = predec_mod[cycle];
  end
  predec_t predec_dyn;
  assign predec_dyn = predec_multi[is_mod_i][cur_i];
  assign oa_o   = predec_dyn.op_a_qw_sel;
  assign en_o   = predec_dyn.mul_add_en;
  assign mul2_o = predec_mul[2].mul_add_en;
endmodule
