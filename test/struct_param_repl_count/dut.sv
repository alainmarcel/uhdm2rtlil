// Repro of CVA6 instr_scan rvc_imm_o bug: a replication whose COUNT is an
// arithmetic expression over a struct-parameter field
// (`{{53+CVA6Cfg.VLEN-64{instr_i[12]}}, ...}`).  UHDM zero-filled instead of
// replicating the sign bit (only visible when the replicated bit is 1).
package cfg_pkg;
  typedef struct packed {
    int unsigned VLEN;
    int unsigned XLEN;
  } cfg_t;
  localparam cfg_t Cfg = '{VLEN: 64, XLEN: 64};
endpackage

module struct_param_repl_count
  import cfg_pkg::*;
#(
    parameter cfg_t CVA6Cfg = cfg_pkg::Cfg
) (
    input  logic [31:0]             instr_i,
    output logic [CVA6Cfg.VLEN-1:0] imm_o
);
  assign imm_o = (instr_i[14])
      ? {{56 + CVA6Cfg.VLEN - 64 {instr_i[12]}}, instr_i[6:5], instr_i[2], instr_i[11:10], instr_i[4:3], 1'b0}
      : {{53 + CVA6Cfg.VLEN - 64 {instr_i[12]}}, instr_i[8], instr_i[10:9], instr_i[6], instr_i[7], instr_i[2], instr_i[11], instr_i[5:3], 1'b0};
endmodule
