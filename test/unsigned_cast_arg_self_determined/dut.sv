// The argument of `$unsigned(e)` / `$signed(e)` is SELF-DETERMINED (LRM
// 6.24.2): `$unsigned(wr_ptr - rd_ptr) >= 2**W-4` must compute the 6-bit
// pointer difference at 6 bits (0 - 63 wraps to 1) and only then compare at
// the 32-bit width of the right-hand side.  read_uhdm let the argument
// inherit the comparison's context width, so the difference was computed at
// 64 bits (0 - 63 = a huge value) and verilog-pcie dma_if_pcie_us_rd's
// status FIFO reported full with one entry (co-sim divergence).  The un-cast
// twin `(a - b) >= 28` IS context-determined at 32 bits and stays as it was.
module unsigned_cast_arg_self_determined (
  input  logic [5:0] wr_ptr,
  input  logic [5:0] rd_ptr,
  input  logic signed [5:0] s,
  output logic full,
  output logic full_uncast,
  output logic full_narrow,
  output logic [7:0] diff,
  output logic [7:0] sdiff
);
  localparam W = 5;
  assign full        = $unsigned(wr_ptr - rd_ptr) >= 2**W-4;
  assign full_uncast = (wr_ptr - rd_ptr) >= 2**W-4;
  assign full_narrow = $unsigned(wr_ptr - rd_ptr) >= 6'd28;
  assign diff        = $unsigned(wr_ptr - rd_ptr);
  assign sdiff       = $signed(s - 6'sd1);
endmodule
