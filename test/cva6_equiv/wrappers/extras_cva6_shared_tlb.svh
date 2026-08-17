  // From cva6_mmu.sv (real instantiation site)
  localparam HYP_EXT = CVA6Cfg.RVH ? 1 : 0;
  localparam type pte_cva6_t = struct packed {
    logic n;
    logic [8:0] reserved;
    logic [CVA6Cfg.PPNW-1:0] ppn;
    logic [1:0] rsw;
    logic d;
    logic a;
    logic g;
    logic u;
    logic x;
    logic w;
    logic r;
    logic v;
  };
  localparam type tlb_update_cva6_t = struct packed {
    logic valid;
    logic is_napot_64k;
    logic [CVA6Cfg.PtLevels-2:0][HYP_EXT:0] is_page;
    logic [CVA6Cfg.VpnLen-1:0] vpn;
    logic [CVA6Cfg.ASID_WIDTH-1:0] asid;
    logic [CVA6Cfg.VMID_WIDTH-1:0] vmid;
    logic [HYP_EXT*2:0] v_st_enbl;
    pte_cva6_t content;
    pte_cva6_t g_content;
  };
