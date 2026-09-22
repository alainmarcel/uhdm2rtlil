// Several writes to one memory, some of them guarded by a parameter that is
// FALSE in this instantiation, so those branches fold away.
//
// The $memwr control wires are created for every write site, and EN and DATA
// were defaulted at the process root ("no write by default") -- but the
// ADDRESS was not.  A write whose branch folds away then leaves the $memwr
// cell's ADDR input with no driver at all.
//
// verilog-axis's axis_fifo guards two of its four writes with MARK_WHEN_FULL
// (0 by default): 24 undriven address bits per FIFO, in EVERY axis_* FIFO of
// verilog-ethernet and verilog-pcie, and 48 in each eth_mac_*_fifo, which
// instantiate two.
module dut #(
  parameter AW = 4,
  parameter W  = 8,
  parameter MARK_WHEN_FULL = 0     // the dead-branch guard
) (
  input               clk,
  input               we,
  input               full,
  input               mark,
  input  [AW-1:0]     wr_addr,
  input  [AW-1:0]     rd_addr,
  input  [W-1:0]      din,
  output [W-1:0]      dout
);
  reg [W-1:0] mem [(2**AW)-1:0];
  reg [W-1:0] rdata;

  always @(posedge clk) begin
    if (we) begin
      if (full && MARK_WHEN_FULL) begin
        // FOLDS AWAY when MARK_WHEN_FULL = 0 -- this write site's $memwr
        // address wire is the one that used to be left undriven
        mem[wr_addr] <= din;
      end else if (mark && MARK_WHEN_FULL) begin
        // a second folded-away site, so the test covers more than one
        mem[wr_addr] <= ~din;
      end else begin
        // the live write
        mem[wr_addr] <= din;
      end
    end
    rdata <= mem[rd_addr];
  end
  assign dout = rdata;
endmodule
