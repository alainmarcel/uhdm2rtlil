// A byte-enabled write into a GENERATE-scope memory:
//   for (n...) begin : seg  reg [15:0] mem_reg [7:0];
//     for (i...) if (we[n] && be[n*2+i]) mem_reg[wa][i*8 +: 8] <= wd[...];
// (verilog-pcie dma_psdpram's per-segment RAM).  The memory-write ports
// are registered under the SCOPED name (`genblk1[0].mem_reg`) while the
// var_select LHS names the memory bare, so the write found no port, was
// imported as a memory READ and its data landed on the $memrd wire: the RAM
// never stored anything (rd_resp_data all zero, a double-driven $procmux in
// proc).  At module scope the same write was fine — a generate-scope parity
// gap.  The port lookup now falls back to the scoped name.
module genscope_memory_byte_enable_write (
  input  logic        clk,
  input  logic [1:0]  we,
  input  logic [3:0]  be,
  input  logic [5:0]  wa,
  input  logic [31:0] wd,
  input  logic [1:0]  re,
  input  logic [5:0]  ra,
  output logic [31:0] q
);
  genvar n;
  generate
    for (n = 0; n < 2; n = n + 1) begin
      reg [15:0] mem_reg [7:0];
      reg [15:0] q_reg = 0;
      always @(posedge clk) begin
        for (int i = 0; i < 2; i = i + 1) begin
          if (we[n] && be[n*2+i]) begin
            mem_reg[wa[3*n +: 3]][i*8 +: 8] <= wd[16*n+i*8 +: 8];
          end
        end
      end
      always @(posedge clk) begin
        if (re[n]) q_reg <= mem_reg[ra[3*n +: 3]];
      end
      assign q[16*n +: 16] = q_reg;
    end
  endgenerate
endmodule
