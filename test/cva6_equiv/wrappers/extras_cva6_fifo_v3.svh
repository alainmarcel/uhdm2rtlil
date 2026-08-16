  // Representative binding: amo_buffer's i_amo_fifo (DEPTH=1, struct dtype).
  // The wrapper's ADDR_DEPTH-consuming usage_o port sizes from DEPTH.
  localparam DEPTH = 1;
  localparam type dtype = struct packed {
    ariane_pkg::amo_t        op;
    logic [CVA6Cfg.PLEN-1:0] paddr;
    logic [CVA6Cfg.XLEN-1:0] data;
    logic [1:0]              size;
  };
  localparam ADDR_DEPTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;
