// A PACKED array with a non-zero ASCENDING range, written AND read at dynamic
// indices.
//
// An ascending declared range puts the FIRST element at the TOP of the word
// (the LRM makes `el_t [1:4] a`'s a[1] the leftmost), and the READ path
// mirrors the index as `(hi - i) * elem_w`.  The dynamic WRITE subtracted the
// LOW bound instead, so the two disagreed and every element landed in the
// wrong slot -- register n was stored where the read expected register 32-n.
//
// This is scr1_pipe_mprf's register file:
//   typedef logic [`SCR1_XLEN-1:0] type_scr1_mprf_v;
//   type_scr1_mprf_v [1:`SCR1_MPRF_SIZE-1] mprf_int;
// written `mprf_int[rd_addr] <= rd_data` and read `mprf_int[rs1_addr]`.
// The row went from 265 co-sim divergences to equivalent.
//
// The UNPACKED twin is here on purpose: an unpacked array of one-bit elements
// keeps the RAW index on the read side, so its write must keep `idx - low`.
// Mirroring that one was tried in #1056 and was wrong, and this test pins
// both conventions at once.
module dut (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       we,
    input  logic [1:0] waddr_lo,   // the index is 1 + waddr_lo, so it is
    input  logic [1:0] raddr_lo,   // ALWAYS in range for [1:4]
    input  logic [7:0] wdata,
    output logic [7:0] rdata_packed,
    output logic [31:0] whole_packed,
    output logic       rdata_unpacked_bit,
    output logic [3:0] whole_unpacked_bits
);
  // An out-of-range dynamic index reads as X in the RTL but as a real bit in
  // any netlist, which is a co-sim artefact and not what this test is about;
  // scr1 guards the same way (`wr_req_vd = w_req & |rd_addr`).  Keep every
  // index inside [1:4] so the only thing under test is the element OFFSET.
  logic [2:0] waddr, raddr;
  assign waddr = 3'd1 + {1'b0, waddr_lo};
  assign raddr = 3'd1 + {1'b0, raddr_lo};

  typedef logic [7:0] el_t;
  el_t [1:4] parr;           // PACKED, ascending, base 1  -> mirrored
  logic      uarr [1:4];     // UNPACKED one-bit elements  -> raw index

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      parr <= '{default: '0};
      for (int i = 1; i <= 4; i++) uarr[i] <= 1'b0;
    end else if (we) begin
      parr[waddr] <= wdata;
      uarr[waddr] <= wdata[0];
    end
  end

  // dynamic reads
  assign rdata_packed       = parr[raddr];
  assign rdata_unpacked_bit = uarr[raddr];
  // the element order, brought out so a wrong slot is visible and not just
  // self-consistently wrong
  assign whole_packed        = {parr[4], parr[3], parr[2], parr[1]};
  assign whole_unpacked_bits = {uarr[4], uarr[3], uarr[2], uarr[1]};
endmodule
