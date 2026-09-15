// Indexed part-selects `[off +: size]` / `[off -: size]` on a 2-D PACKED array
// (`logic [N-1:0][7:0]`) select whole ELEMENTS (bytes), on both sides of a
// continuous assign (OpenTitan otp_ctrl: `lc_otp_program_data[LcStateOffset
// -LifeCycleOffset +: LcStateSize] = lc_otp_program_i.state;`).  read_uhdm
// treated off/size as BITS: only 88 of the 704 lc_data_i bits were driven in
// the Egret top.
module packed2d_indexed_partsel_cont_assign_elems #(parameter int N = 6) (
  input  logic [23:0]         state_i,
  input  logic [15:0]         count_i,
  input  logic [N-1:0][7:0]   src_i,
  output logic [N*8-1:0]      flat_o,
  input  logic [1:0]          sel_i,
  output logic [15:0]         mid_o,
  output logic [15:0]         dyn_o,
  output logic [15:0]         dyn_dn_o
);
  localparam int StateOff = 0, StateSize = 3, CntOff = 3, CntSize = 2;
  logic [N-1:0][7:0] prog;
  assign prog[StateOff +: StateSize] = state_i;
  assign prog[CntOff +: CntSize]     = count_i;
  assign prog[N-1 -: 1]              = 8'hA5;
  assign flat_o = prog;
  assign mid_o    = src_i[2 +: 2];
  assign dyn_o    = src_i[sel_i +: 2];
  assign dyn_dn_o = src_i[sel_i + 3'd2 -: 2];
endmodule
