// Enum members whose values are concatenations of package parameters wider
// than 64 bits (OpenTitan lc_ctrl_state_pkg: the 320-bit lc_state_e and
// 384-bit lc_cnt_e members `{A11, B10, …}`).  Surelog's 64-bit value
// evaluator could not hold them and left the members without a value; every
// `case` arm on those states compared against 0 and never matched (lc_ctrl's
// state decode / transition / FSM).  Surelog #4175 folds the member expression
// through the expression compiler (BIN string), and the reader parses wide
// values with the member's typespec width.
package ewc_pkg;
  parameter logic [31:0] A = 32'hF00D_BEEF, B = 32'h1234_5678, C = 32'hDEAD_C0DE, D = 32'h0BAD_F00D;
  typedef enum logic [127:0] {
    Cnt0 = {A, B, C, D},
    Cnt1 = {B, C, D, A},
    Cnt2 = {C, D, A, B},
    Cnt3 = {D, A, B, C}
  } cnt_e;
endpackage
module enum_wide_concat_member_values import ewc_pkg::*; (input cnt_e c_i, input logic inc_i, output cnt_e n_o, output logic oflw_o);
  always_comb begin
    n_o = c_i; oflw_o = 1'b0;
    if (inc_i) begin
      unique case (c_i)
        Cnt0: n_o = Cnt1;
        Cnt1: n_o = Cnt2;
        Cnt2: n_o = Cnt3;
        Cnt3: oflw_o = 1'b1;
        default: oflw_o = 1'b1;
      endcase
    end
  end
endmodule
