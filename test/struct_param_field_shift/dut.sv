// Reproducer for CVA6 wt_dcache_wbuffer gen_tx_vld: a FIELD of a struct-typed
// parameter (`Cfg.XLEN_ALIGN_BYTES`) used as a SHIFT AMOUNT / replication count
// in a generate-scope continuous assignment, with a CONSTANT left operand (so
// the whole shift const-folds).  Two bugs surfaced here:
//   1. `Cfg.FIELD` in expression context was only width-resolved (returned X),
//      never value-resolved -> garbage.  Fixed via ExprEval in import_hier_path.
//   2. RTLIL::const_shl(result_len=-1) does resize((size_t)-1) -> throws
//      std::vector::_M_fill_insert.  Fixed by passing the self-determined width.
package cfg_pkg;
  typedef struct packed {
    int unsigned XLEN;
    int unsigned XLEN_ALIGN_BYTES;
  } cfg_t;
  function automatic cfg_t build_config(int unsigned xlen);
    cfg_t cfg;
    cfg.XLEN = xlen;
    cfg.XLEN_ALIGN_BYTES = $clog2(xlen / 8);   // = 3 for xlen=64
    return cfg;
  endfunction
  localparam cfg_t DefaultCfg = build_config(64);
endpackage

module struct_param_field_shift #(
    parameter cfg_pkg::cfg_t Cfg = cfg_pkg::DefaultCfg
) (
    input  logic [3:0]           sel_i,
    output logic [Cfg.XLEN-1:0]  y_o
);
  logic [Cfg.XLEN-1:0] acc [0:1];
  for (genvar k = 0; k < 2; k++) begin : gen_blk
    // CONST left operand shifted by the struct-param field -> const-fold path;
    // prepend field-count zero bits (replication count = struct-param field).
    assign acc[k] = {{Cfg.XLEN_ALIGN_BYTES{1'b0}},
                     (8'hAB + k) << Cfg.XLEN_ALIGN_BYTES};
  end
  assign y_o = sel_i[0] ? acc[0] : acc[1];
endmodule
