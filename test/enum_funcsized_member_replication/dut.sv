// An enum whose base width is a package FUNCTION result
// (`enum logic [vbits(NumLcStates)-1:0]`, lc_ctrl_state_pkg::dec_lc_state_e):
// Surelog's value evaluator cannot size the base and stamps vpiSize 64 on
// every member, so ExprEval folded `{DecLcStateNumRep{DecLcStInvalid}}` with
// 64-bit members and the 30-bit result held ONE copy (lc_ctrl_state_decode),
// and `trans_target_i == {6{DecLcStScrap}}` never matched (state_transition).
// The reader now sizes enum members from the enum's base typespec and keeps
// operations with such mis-sized members out of ExprEval.
package efm_util_pkg;
  function automatic integer vbits(integer value);
    return (value == 1) ? 1 : $clog2(value);
  endfunction
endpackage
package efm_pkg;
  parameter int NumLcStates = 21;
  parameter int DecLcStateWidth = efm_util_pkg::vbits(NumLcStates);
  parameter int DecLcStateNumRep = 32/DecLcStateWidth;
  typedef enum logic [DecLcStateWidth-1:0] {
    DecLcStRaw = 0, DecLcStTestUnlocked0 = 1, DecLcStScrap = 20, DecLcStInvalid = 22
  } dec_lc_state_e;
  typedef dec_lc_state_e [DecLcStateNumRep-1:0] ext_dec_lc_state_t;
endpackage
module enum_funcsized_member_replication import efm_pkg::*; (
  input  logic [1:0] s_i,
  input  ext_dec_lc_state_t trans_target_i,
  output ext_dec_lc_state_t dec_o,
  output logic scrap_o);
  always_comb begin
    dec_o = {DecLcStateNumRep{DecLcStInvalid}};
    unique case (s_i)
      2'd0: dec_o = {DecLcStateNumRep{DecLcStRaw}};
      2'd1: dec_o = {DecLcStateNumRep{DecLcStTestUnlocked0}};
      2'd2: dec_o = {DecLcStateNumRep{DecLcStScrap}};
      default: ;
    endcase
    scrap_o = (trans_target_i == {DecLcStateNumRep{DecLcStScrap}});
  end
endmodule
