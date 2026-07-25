// A reset assignment in an async-reset always_ff guarded by a STRUCT-PARAMETER
// FIELD that is compile-time false (`Cfg.RVH == 0`).
//
// eval_param_struct_field resolves `Cfg.RVH` to a 32-bit constant 0, but the
// `if (condition.size() > 1) ReduceBool(...)` step then turned that CONSTANT
// into a $reduce_bool CELL, so the guard was no longer recognized as constant
// and the `if` emitted a runtime switch — giving `guarded_q` a conditional
// (non-constant) async-reset value.  `proc`/PROC_ARST then aborted with
//   ERROR: Async reset ... yields non-constant value N'mmm..m for signal guarded_q
// Fix: reduce a CONSTANT multi-bit condition to a constant bit (not a cell) so
// the const-fold takes the (false) branch and drops the dead reset assignment;
// `guarded_q` becomes a plain clocked DFF that holds during reset ($dffe),
// matching read_verilog / slang.  (Mirrors CVA6 cva6_ptw.sv `if (CVA6Cfg.RVH)
// gpaddr_q <= '0` with RVH==0.)
package cfg_pkg;
  typedef struct packed {
    int unsigned XLEN;
    bit          RVH;
  } cfg_t;
  localparam cfg_t Cfg = '{XLEN: 64, RVH: 1'b0};
endpackage

module ff_dead_guarded_reset
  import cfg_pkg::*;
#(
    parameter cfg_t Cfg = cfg_pkg::Cfg
) (
    input  logic       clk_i,
    input  logic       rst_ni,
    input  logic [7:0] d_i,
    output logic [7:0] guarded_q,
    output logic [7:0] normal_q
);
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      normal_q <= '0;
      if (Cfg.RVH) begin
        guarded_q <= '0;
      end
    end else begin
      normal_q  <= d_i;
      guarded_q <= d_i;
    end
  end
endmodule
