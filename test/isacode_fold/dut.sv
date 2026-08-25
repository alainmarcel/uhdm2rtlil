// csr_regfile IsaCode shape: localparam OR-chain of casts of struct-param
// fields shifted into place. The config struct is >64 bits (int fields
// first), so it resolves via the complex-value path; some later bit-fields
// folded to 0 in the misa read (CVA6 RVC/RVD/RVF/RVS/RVU lost).
package icfg_pkg;
  typedef struct packed {
    int unsigned XLEN;
    int unsigned VLEN;
    bit RVA;
    bit RVB;
    bit ZKN;
    bit RVV;
    bit RVC;
    bit RVH;
    bit RVF;
    bit RVD;
    bit RVS;
    bit RVU;
  } cfg_t;
  localparam cfg_t Cfg = '{
    XLEN: 64, VLEN: 64,
    RVA: 1, RVB: 1, ZKN: 0, RVV: 0, RVC: 1, RVH: 0,
    RVF: 1, RVD: 1, RVS: 1, RVU: 1
  };
endpackage

module isacode_fold #(
  parameter icfg_pkg::cfg_t CVA6Cfg = icfg_pkg::Cfg
) (
  output logic [63:0] isa_o
);
  localparam logic [CVA6Cfg.XLEN-1:0] IsaCode =
      (CVA6Cfg.XLEN'(CVA6Cfg.RVA) << 0)
    | (CVA6Cfg.XLEN'(CVA6Cfg.RVB) << 1)
    | (CVA6Cfg.XLEN'(CVA6Cfg.RVC) << 2)
    | (CVA6Cfg.XLEN'(CVA6Cfg.RVD) << 3)
    | (CVA6Cfg.XLEN'(CVA6Cfg.RVF) << 5)
    | (CVA6Cfg.XLEN'(CVA6Cfg.RVH) << 7)
    | (CVA6Cfg.XLEN'(1) << 8)
    | (CVA6Cfg.XLEN'(1) << 12)
    | (CVA6Cfg.XLEN'(CVA6Cfg.RVS) << 18)
    | (CVA6Cfg.XLEN'(CVA6Cfg.RVU) << 20);
  assign isa_o = IsaCode;
endmodule
