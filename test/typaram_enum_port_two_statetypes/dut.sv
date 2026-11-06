// Two modules each declare their OWN `statetype` enum (2 and 4 bits) and bind
// it to the same `parameter type TYPE` of cvw's flopenl.  The TYPE ports must
// be sized from the ENUM, so the two instances get distinct paramods: in cvw
// the port's own typespec stays the generic `logic [WIDTH-1:0]` (8) and the
// enum lives only on the port's Low_conn enum_var; get_width preferred that
// actual for struct/array vars only, measured hptw's 4-bit walker state as 8,
// and folded the instance onto ebufsmarb's 2-bit paramod -- the page-table
// walker FSM was stuck from reset (wallypipelinedcore, 298 diverging
// co-simulated cycles).  NB: on small designs Surelog binds the enum's base
// type into the port typespec itself, so this test passes on the control
// plugin too; the structural gate pins the two paramod widths.
module flopenl #(parameter WIDTH = 8, parameter type TYPE = logic [WIDTH-1:0]) (
  input  logic clk, load, en,
  input  TYPE  d,
  input  TYPE  val,
  output TYPE  q);
  always_ff @(posedge clk)
    if (load)    q <= val;
    else if (en) q <= d;
endmodule

// Two modules that each declare their OWN `statetype` and bind it to the
// same TYPE parameter: the arbiter's is 2 bits, the walker's 4 bits.
module arb (input logic clk, reset, input logic [1:0] next_i, output logic [1:0] state_o);
  typedef enum logic [1:0] {IDLE, ARBITRATE} statetype;
  statetype CurrState, NextState;
  assign NextState = statetype'(next_i);
  flopenl #(.TYPE(statetype)) busreg(clk, reset, 1'b1, NextState, IDLE, CurrState);
  assign state_o = CurrState;
endmodule

package cfgpkg;
  typedef struct packed { int XLEN; logic SV39; } cvw_t;
  localparam cvw_t DEF = '{XLEN: 64, SV39: 1'b1};
endpackage
module walker import cfgpkg::*; #(parameter cvw_t P) (input logic clk, reset, input logic [3:0] next_i, output logic [3:0] state_o);
  typedef enum logic [3:0] {L0_ADR, L0_RD, L1_ADR, L1_RD, L2_ADR, L2_RD, L3_ADR, L3_RD,
                            LEAF, IDLE, UPDATE_PTE, FAULT} statetype;
  statetype WalkerState, NextWalkerState;
  assign NextWalkerState = statetype'(next_i);
  flopenl #(.TYPE(statetype)) WalkerStateReg(clk, reset, 1'b1, NextWalkerState, IDLE, WalkerState);
  assign state_o = WalkerState;
endmodule

module lsu import cfgpkg::*; #(parameter cvw_t P) (input logic clk, reset, input logic [3:0] next_i, output logic [3:0] state_o);
  walker #(P) hptw (clk, reset, next_i, state_o);
endmodule

module dut import cfgpkg::*; #(parameter cvw_t P = DEF) (
  input  logic       clk,
  input  logic       reset,
  input  logic [1:0] anext_i,
  input  logic [3:0] wnext_i,
  output logic [1:0] astate_o,
  output logic [3:0] wstate_o
);
  arb    a (clk, reset, anext_i, astate_o);
  lsu #(P) lsu (clk, reset, wnext_i, wstate_o);
endmodule
