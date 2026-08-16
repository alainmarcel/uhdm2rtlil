  // From issue_stage.sv (real instantiation site)
  localparam type rs3_len_t = logic [(CVA6Cfg.NrRgprPorts == 3 ? CVA6Cfg.XLEN : CVA6Cfg.FLen)-1:0];
  localparam type forwarding_t = struct packed {
    logic [CVA6Cfg.NR_SB_ENTRIES-1:0] still_issued;
    logic [CVA6Cfg.TRANS_ID_BITS-1:0] issue_pointer;
    writeback_t [CVA6Cfg.NrWbPorts-1:0] wb;
    scoreboard_entry_t [CVA6Cfg.NR_SB_ENTRIES-1:0] sbe;
  };
