// CVA6 cva6_tlb tag-update repro: an EXPRESSION-width size cast
// `((Cfg.PtLevels + HYP_EXT) * (Cfg.VpnLen / Cfg.PtLevels))'(vpn)` leaves an
// integer_typespec with EMPTY VpiValue and the width in its Expr(); the
// importer defaulted the cast to 32 bits, and inside the enclosing concat
// the oversized cast STOLE the top 5 bits of the stored asid (TLB lookups
// mismatched on asid).
package ewc_pkg;
  typedef struct packed {
    int unsigned PtLevels;
    int unsigned VpnLen;
  } cfg_t;
endpackage

module expr_width_cast #(
  parameter ewc_pkg::cfg_t Cfg = '{PtLevels: 3, VpnLen: 27},
  parameter int unsigned HYP_EXT = 0
)(
  input  logic [26:0] vpn,
  input  logic [15:0] asid,
  output logic [44:0] tag
);
  always_comb begin
    tag = {
      asid,
      ((Cfg.PtLevels + HYP_EXT) * (Cfg.VpnLen / Cfg.PtLevels))'(vpn),
      1'b1,
      1'b0
    };
  end
endmodule
