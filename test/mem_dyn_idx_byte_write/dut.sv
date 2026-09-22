// Byte-enabled write to a DYNAMICALLY indexed memory word, in the shape every
// firtool-generated SRAM model uses (XiangShan's array_*x* macros):
//
//     Memory[RW0_addr][32'h1B +: 27] <= RW0_wdata[53:27];
//
// The whole write -- array index AND intra-word lane -- arrives from Surelog as
// a single `var_select`, so a classifier that only looks at `bit_select` never
// sees the dynamic address.  The array is then declared constant-indexed and
// degraded to per-element registers with an $eq/$mux decoder per element, which
// for XiangShan's 8192x432 SRAM meant 278558 cells instead of one $mem.
module dut(
  input             clk,
  input             en,
  input             wmode,
  input      [1:0]  addr,
  input      [9:0]  wdata,
  input      [1:0]  wmask,
  output     [9:0]  rdata,
  output     [4:0]  lane0_of_word3
);
  reg [9:0] Memory[0:3];
  reg [1:0] raddr_d0;

  always @(posedge clk) begin
    if (en)
      raddr_d0 <= addr;
    if (en & wmask[0] & wmode)
      Memory[addr][32'h0 +: 5] <= wdata[4:0];
    if (en & wmask[1] & wmode)
      Memory[addr][32'h5 +: 5] <= wdata[9:5];
  end

  // Dynamic read of the whole word ...
  assign rdata = Memory[raddr_d0];
  // ... and a CONSTANT-index lane read, so a dropped lane write is visible on
  // its own output rather than only through the registered read port.
  assign lane0_of_word3 = Memory[3][4:0];
endmodule
