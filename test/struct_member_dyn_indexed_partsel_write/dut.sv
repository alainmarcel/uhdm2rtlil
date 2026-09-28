// An indexed part-select write with a DYNAMIC base into a packed-struct
// member -- `req_o.wdata[axi_offset +: 64] = wdata;` under an `if` in an
// always_comb -- was dropped by read_uhdm: the member kept the block's
// default.  A constant base (`[0 +: 64]`) and a whole-member write were
// fine.  CVA6 cache_ctrl's WAIT_REFILL_GNT arm builds miss_req_o this way
// (wdata and be), so every refill request carried zero data / byte enables:
// the sweep row differed and the co-sim diverged on the first miss.
package p;
  typedef struct packed { logic valid; logic [7:0] be; logic [63:0] wdata; logic bypass; } req_t;
endpackage
module dut (
  input  logic [11:0] index,
  input  logic [5:0]  off_i,
  input  logic [63:0] wdata,
  input  logic [7:0]  be,
  input  logic        go,
  output p::req_t     req_auto,
  output p::req_t     req_port,
  output p::req_t     req_const
);
  // the CVA6 shape: a block-local automatic offset (always 0 at XLEN 64)
  always_comb begin
    automatic logic [5:0] axi_offset;
    axi_offset = (index >> 3) << 6;
    req_auto = '0;
    if (go) begin
      req_auto.valid = 1'b1;
      req_auto.be[axi_offset>>3 +: 8] = be;
      req_auto.wdata[axi_offset +: 64] = wdata;
    end
  end
  // a genuinely variable base from a port
  always_comb begin
    req_port = '0;
    if (go) begin
      req_port.valid = 1'b1;
      req_port.wdata[{off_i[2:0], 3'b000} +: 8] = wdata[7:0];   // byte-aligned, in range (a partially out-of-range slice is a known Verilator spill artefact in co-sim)
    end
  end
  // constant base: the reference shape that already worked
  always_comb begin
    req_const = '0;
    if (go) begin
      req_const.valid = 1'b1;
      req_const.wdata[0 +: 64] = wdata;
      req_const.be[0 +: 8] = be;
    end
  end
endmodule
