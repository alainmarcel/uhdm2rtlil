// Enum members whose values are SIZE CASTS of an unsized literal, the width a
// $unit parameter expression -- SCR1 scr1_dm.sv's type_scr1_abs_err_e:
//   ABS_ERR_NOHALT = (SCR1_DBG_ABSTRACTCS_CMDERR_WDTH+1)'('d4)
// Surelog's ExprBuilder has no cast; the enum path forced its invalid result
// valid and published INT:0 for every such member, so every arm below drove 0.

localparam int unsigned W_HI = 10;
localparam int unsigned W_LO = 8;
localparam int unsigned W = W_HI - W_LO;
module enum_sized_cast_member (input logic [1:0] s, output logic [2:0] o);
  typedef enum logic [W:0] {
    E_NONE   = (W+1)'('d0),
    E_BUSY   = (W+1)'('d1),
    E_CMD    = (W+1)'('d2),
    E_EXC    = (W+1)'('d3),
    E_NOHALT = (W+1)'('d4)
  } err_e;
  err_e e;
  always_comb begin
    case (s)
      2'd0: e = E_BUSY;
      2'd1: e = E_CMD;
      2'd2: e = E_EXC;
      default: e = E_NOHALT;
    endcase
  end
  assign o = e;
endmodule
