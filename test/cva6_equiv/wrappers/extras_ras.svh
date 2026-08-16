  // From frontend.sv (real instantiation site of ras)
  localparam type ras_t = struct packed {
    logic                    valid;
    logic [CVA6Cfg.VLEN-1:0] ra;
  };
