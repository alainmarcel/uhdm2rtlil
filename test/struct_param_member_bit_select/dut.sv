// A BIT-SELECT into a vector member of a STRUCT PARAMETER: CVA6's
// `if (!CVA6Cfg.PMPEntryReadOnly[i])` on `bit [63:0] PMPEntryReadOnly`.  The
// indexed-member fold knew only element selects over the member's packed
// DIMENSIONS, so one index on a plain vector (no dimension at all) bailed,
// the bit read as X, the `if` folded to its ELSE arm at import time and the
// csr_regfile never wrote a pmpcfg entry (cva6-rv32 csr_regfile, formal
// `differs`).  Three shapes: a loop-constant bit of a 1-D member, a runtime
// bit of the same, and a bit of the leaf of a 2-D member.  UHDM-only
// (read_verilog cannot parse a struct parameter); the slang miter is the gate.
package p;
  typedef struct packed {
    logic [3:0][7:0] Tab;         // 2-D: Tab[i] is a byte, Tab[i][b] a bit
    bit   [15:0]     ReadOnly;    // 1-D: ReadOnly[i] is a bit
    int unsigned     N;
  } cfg_t;
  localparam cfg_t CFG = '{
    Tab:      {8'hA5, 8'h3C, 8'hF0, 8'h0F},   // Tab[3]=A5 Tab[2]=3C Tab[1]=F0 Tab[0]=0F
    ReadOnly: 16'b0000_0000_1010_0101,        // bits 0,2,5,7 set
    N:        8
  };
  // CVA6's spelling: the struct parameter is BUILT BY A CONSTANT FUNCTION
  // (build_config_pkg::build_config), which the reader folds on a different
  // path from a pattern-valued one.
  function automatic cfg_t build(cfg_t c);
    build = c;
    build.ReadOnly = c.ReadOnly | 16'b0001_0000_0000_0000;   // bit 12 set too
  endfunction
  localparam cfg_t CFG_FN = build(CFG);
endpackage

module dut #(
  parameter p::cfg_t Cfg   = p::CFG,
  parameter p::cfg_t CfgFn = p::CFG_FN
) (
  input  logic [7:0] d_i,
  input  logic [7:0] q_i,
  input  logic [3:0] sel_i,
  input  logic [1:0] row_i,
  output logic [7:0] next_o,     // next_o[i] = ReadOnly[i] ? q_i[i] : d_i[i]
  output logic       ro_o,       // ReadOnly[sel_i]
  output logic       tab_c_o,    // Tab[2][5] = bit 5 of 3C = 1
  output logic [7:0] fn_next_o,  // same loop over the function-built parameter
  output logic       fn_ro_o,    // CfgFn.ReadOnly[sel_i]: bit 12 set as well
  output logic       fn_tab_o    // CfgFn.Tab[row_i][sel_i[2:0]]: a bit of the 2-D member's leaf
);
  always_comb begin
    for (int i = 0; i < 8; i++) begin
      if (i < Cfg.N) begin
        if (!Cfg.ReadOnly[i]) next_o[i] = d_i[i];
        else                  next_o[i] = q_i[i];
      end else next_o[i] = 1'b0;
    end
  end
  assign ro_o    = Cfg.ReadOnly[sel_i];
  // (`Cfg.Tab[row_i][sel_i[2:0]]` on the PATTERN-valued parameter is not here:
  // Surelog folds that two-index runtime select to a constant 1 -- a separate
  // Surelog defect; the function-built parameter below keeps the hier_path.)
  assign tab_c_o = Cfg.Tab[2][5];
  always_comb begin
    for (int i = 0; i < 8; i++) begin
      if (i < CfgFn.N) begin
        if (!CfgFn.ReadOnly[i]) fn_next_o[i] = d_i[i];
        else                    fn_next_o[i] = q_i[i];
      end else fn_next_o[i] = 1'b0;
    end
  end
  assign fn_ro_o  = CfgFn.ReadOnly[sel_i];
  assign fn_tab_o = CfgFn.Tab[row_i][sel_i[2:0]];
endmodule
