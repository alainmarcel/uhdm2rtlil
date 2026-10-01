// A dynamic read of a packed-array ROW whose INDEX is an indexed part-select
// of a vector declared with a non-zero LSB -- VeeR's DCCM read path:
//
//   logic [(WB+BB-1):WB] addr_q;                       // `logic [3:2]`
//   rvdff #(BB) ff (.din(addr[WB +: BB]), .dout(addr_q[WB +: BB]), ...);
//   assign rd = bank_dout[addr_q[WB +: BB]][W-1:0];
//
// The index has to be mapped through the DECLARED range (`addr_q[2+:2]` is
// bits [1:0] of a 2-bit wire), both where it is READ and where it is the
// actual of an instance OUTPUT port.  Unmapped it looked out of range: the
// select returned an empty SigSpec, so `addr_q` had no driver at all and the
// row collapsed to bank 0.
module ff2 #(parameter int W = 1) (input logic clk, input logic [W-1:0] d,
                                   output logic [W-1:0] q);
  always_ff @(posedge clk) q <= d;
endmodule

module dut (
  input  logic              clk,
  input  logic [3:0]        addr_lo,
  input  logic [5:2]        addr_wide,       // non-zero LSB, slice fits
  input  logic [3:0][7:0]   bank_dout,
  output logic [7:0]        rd_ff,           // index through an instance output
  output logic [7:0]        rd_q,            // index through an always_ff
  output logic [7:0]        rd_wide          // index from a [5:2] input
);
  localparam int WB = 2;
  localparam int BB = 2;

  // Declared [3:2]: the wire is 2 bits wide and starts at bit 0 in RTLIL.
  logic [(WB+BB-1):WB] addr_i;
  logic [(WB+BB-1):WB] addr_q;

  // The select is the ACTUAL of an instance OUTPUT port.
  ff2 #(.W(BB)) u_ff (.clk(clk), .d(addr_lo[WB +: BB]),
                      .q(addr_i[WB +: BB]));
  always_ff @(posedge clk)
    addr_q[WB +: BB] <= addr_lo[WB +: BB];

  assign rd_ff   = bank_dout[addr_i[WB +: BB]][7:0];
  assign rd_q    = bank_dout[addr_q[WB +: BB]][7:0];
  // Declared [5:2]: `addr_wide[2 +: 2]` FITS the 4-bit wire, so nothing looks
  // out of range -- it simply read bits [3:2] instead of [1:0].
  assign rd_wide = bank_dout[addr_wide[WB +: BB]][7:0];
endmodule
