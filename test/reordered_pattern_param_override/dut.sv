// A struct PARAMETER built from a named pattern with `default` (cv32e40x's
// `DCSR_RESET_VAL = '{xdebugver: XDEBUGVER_STD, stopcount: 1'b1, ..., prv:
// PRIV_LVL_M, default: '0}`), handed to a child's `bit [31:0]` parameter.  Surelog
// hands the override over as a REORDERED (LSB-first) pattern; unpatched read_uhdm
// sized operand k as member k, so the override folded to 0x00088003, not 0x40000413.
package pk;
  typedef enum logic [1:0] { PRIV_LVL_U = 2'b00, PRIV_LVL_M = 2'b11 } privlvl_t;
  typedef enum logic [3:0] { XDEBUGVER_NO = 4'd0, XDEBUGVER_STD = 4'd4 } x_e;
  parameter DBG_CAUSE_NONE = 3'h0;
  typedef struct packed {
    logic [31:28] xdebugver; logic [27:18] zero2; logic ebreakvs; logic ebreakvu; logic ebreakm; logic zero1;
    logic ebreaks; logic ebreaku; logic stepie; logic stopcount; logic stoptime; logic [8:6] cause;
    logic v; logic mprven; logic nmip; logic step; privlvl_t prv;
  } dcsr_t;
  parameter dcsr_t DCSR_RESET_VAL = '{
    xdebugver:  XDEBUGVER_STD,
    stopcount:  1'b1,
    cause:      DBG_CAUSE_NONE,
    mprven:     1'b1,
    prv:        PRIV_LVL_M,
    default:    '0};
endpackage
module child #(parameter bit [31:0] RV = '0) (output logic [31:0] o);
  assign o = RV;
endmodule
module dut import pk::*; (output logic [31:0] o, output logic [31:0] p);
  child #(.RV(DCSR_RESET_VAL)) u (.o(o));
  assign p = DCSR_RESET_VAL;
endmodule
