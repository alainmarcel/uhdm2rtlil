// A ONE-BIT element unpacked array (`reg t [7:0]`) written with a dynamic
// index in a clocked block and read with a dynamic index in a comb block.
// It was never inferred as a memory (the gate required a packed range on the
// element), so the sync write went through the per-element combinational
// path and became `en ? data : 'x` with NO flop: the written value was
// visible the SAME cycle and lost the next one, plus a logic loop.
// verilog-pcie pcie_us_axi_dma_wr's op-table `op_table_bubble_cycle` (260
// co-sim divergences).  The 2-bit sibling `t2` was already a memory, as
// read_slang makes both (`reg [0:0] t [7:0]`).
module unpacked_1bit_array_sync_dyn_write (
  input  logic       clk,
  input  logic       en,
  input  logic [2:0] wp,
  input  logic [2:0] rp,
  input  logic       d,
  input  logic [1:0] d2,
  output logic       q,
  output logic [1:0] q2
);
  reg t[7:0];
  reg [1:0] t2[7:0];
  integer i;
  initial begin
    for (i = 0; i < 8; i = i + 1) begin t[i] = 0; t2[i] = 0; end
  end
  always @(posedge clk) begin
    if (en) begin
      t[wp]  <= d;
      t2[wp] <= d2;
    end
  end
  always @* begin
    q  = t[rp];
    q2 = t2[rp];
  end
endmodule
