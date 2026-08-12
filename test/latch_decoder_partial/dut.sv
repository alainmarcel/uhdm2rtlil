// Repro of CVA6 decoder.sv:1840 `exception_handling` spurious latches on
// SLICES of a struct output: the block writes SOME fields live
// (`instruction_o.ex = ex_i;`) and OTHER fields only under compile-time-false
// guards (`if (Cfg.RVH) instruction_o.ex.tval2 = ...`).  The per-bit
// written-bits map / temp coverage must include LIVE writes only — bits from
// dead-guarded field writes otherwise get an STa update whose only driver is
// the self-hold default, and proc_dlatch latches those slices (slang: 0).
package ldp_cfg_pkg;
  typedef struct packed {
    logic [31:0] XLEN;
    logic        RVH;
    logic        TvalEn;
  } cfg_t;
  localparam cfg_t CfgEmpty = cfg_t'(0);
  function automatic cfg_t build_config();
    cfg_t c;
    c.XLEN   = 64;
    c.RVH    = 1'b0;
    c.TvalEn = 1'b1;
    return c;
  endfunction
  localparam cfg_t CfgDefault = build_config();
endpackage

module ldp_leaf #(
    parameter ldp_cfg_pkg::cfg_t Cfg = ldp_cfg_pkg::CfgEmpty
) (
    input  logic [63:0] cause_i,
    input  logic [63:0] tval_i,
    input  logic [63:0] tval2_i,
    input  logic        valid_i,
    input  logic        take_i,
    output logic [255:0] instr_o
);
  typedef struct packed {
    logic [63:0] cause;
    logic [63:0] tval;
    logic [63:0] tval2;   // RVH-only field
    logic [62:0] tinst;   // RVH-only field
    logic        valid;
  } ex_t;

  ex_t ex_d;

  always_comb begin : exception_handling
    ex_d.cause = cause_i;
    ex_d.valid = valid_i;
    if (Cfg.TvalEn) ex_d.tval = tval_i;
    else ex_d.tval = '0;
    if (Cfg.RVH) begin
      ex_d.tval2 = tval2_i;      // DEAD: RVH == 0
      ex_d.tinst = tval2_i[62:0];
    end
    if (take_i) begin
      ex_d.cause = cause_i ^ 64'h8000000000000000;
    end
  end

  assign instr_o = {ex_d};
endmodule

module latch_decoder_partial (
    input  logic [63:0] cause_i,
    input  logic [63:0] tval_i,
    input  logic [63:0] tval2_i,
    input  logic        valid_i,
    input  logic        take_i,
    output logic [255:0] instr_o
);
  ldp_leaf #(.Cfg(ldp_cfg_pkg::CfgDefault)) u_leaf (.*);
endmodule
