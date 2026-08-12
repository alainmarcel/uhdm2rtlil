// Repro of CVA6 cva6_tlb.sv:298/:184 napot-guard latches: block temps
// (temp_stored_vpn / flush_vpn_masked / stored_vpn_masked / patched_pte)
// assigned ONLY under `if (runtime_bit && Cfg.SvnapotEn)` with SvnapotEn == 0.
// The && guard mixes a RUNTIME first operand with a compile-time-FALSE struct
// param field: const_cond_value must short-circuit on the constant 0 so the
// dead-guard prune drops the temps (slang: 0 latches).  The struct-param field
// (not a plain parameter) is the essential CVA6 ingredient.
package ltn_cfg_pkg;
  typedef struct packed {
    logic [31:0] VpnLen;
    logic        SvnapotEn;
    logic        RVH;
  } cfg_t;
  localparam cfg_t CfgEmpty = cfg_t'(0);
  function automatic cfg_t build_config();
    cfg_t c;
    c.VpnLen    = 27;
    c.SvnapotEn = 1'b0;
    c.RVH       = 1'b0;
    return c;
  endfunction
  localparam cfg_t CfgDefault = build_config();
endpackage

module ltn_leaf #(
    parameter ltn_cfg_pkg::cfg_t Cfg = ltn_cfg_pkg::CfgEmpty
) (
    input  logic [3:0]  napot_i,
    input  logic [26:0] vpn0_i,
    input  logic [26:0] vpn1_i,
    input  logic [26:0] flush_vaddr_i,
    input  logic [63:0] pte_i,
    output logic [3:0]  match_o,
    output logic [63:0] content_o
);
  logic [26:0] temp_stored_vpn;
  logic [26:0] flush_vpn_masked;
  logic [26:0] stored_vpn_masked;
  logic        napot_match;
  logic [63:0] patched_pte;

  always_comb begin : translation
    match_o   = '0;
    content_o = '0;
    for (int unsigned i = 0; i < 4; i++) begin
      if (napot_i[i] && Cfg.SvnapotEn) begin
        temp_stored_vpn   = vpn0_i;
        flush_vpn_masked  = flush_vaddr_i & ~27'hF;
        stored_vpn_masked = temp_stored_vpn & ~27'hF;
        napot_match       = (flush_vpn_masked == stored_vpn_masked);
      end else begin
        napot_match = 1'b0;
      end
      match_o[i] = napot_match | vpn1_i[i];

      if (napot_i[i] && Cfg.SvnapotEn) begin
        patched_pte      = pte_i;
        patched_pte[3:0] = flush_vaddr_i[3:0];
        content_o        = patched_pte;
      end else begin
        content_o = pte_i ^ 64'(i);
      end
    end
  end
endmodule

module latch_tlb_napot (
    input  logic [3:0]  napot_i,
    input  logic [26:0] vpn0_i,
    input  logic [26:0] vpn1_i,
    input  logic [26:0] flush_vaddr_i,
    input  logic [63:0] pte_i,
    output logic [3:0]  match_o,
    output logic [63:0] content_o
);
  ltn_leaf #(.Cfg(ltn_cfg_pkg::CfgDefault)) u_leaf (.*);
endmodule
