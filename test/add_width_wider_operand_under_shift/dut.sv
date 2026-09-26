// An addition whose operand is WIDER than the assignment context, under a
// shift:  cc_next[7:0] = (tlp_count_reg[12:0] + pcie_addr_reg[1:0] - 1) >> 5;
// (verilog-pcie dma_if_pcie_wr's read cycle count).  The add was sized to
// the 8-bit context instead of max(context, operands) = 13, so bits 8..12
// of the sum were lost BEFORE the shift: the cycle count came out as
// 0xff/0x00 instead of 0x3f, `read_last_cycle` never fired and the write
// DMA never reloaded its next command (co-sim divergences under a green
// seq-4 proof).  The add now takes max(context, non-constant operands);
// only constant operands stay capped to the context.
module add_width_wider_operand_under_shift (
  input  logic        clk,
  input  logic        go,
  input  logic [63:0] pcie_addr,
  input  logic [12:0] tlp_count,
  output logic [7:0]  cc,
  output logic        last
);
  localparam TLP_DATA_WIDTH_BYTES = 32;
  reg [63:0] pcie_addr_reg = 0;
  reg [12:0] tlp_count_reg = 0;
  reg [7:0]  cc_reg = 0, cc_next;
  reg        last_reg = 0, last_next;

  always @* begin
    cc_next   = cc_reg;
    last_next = last_reg;
    if (go) begin
      cc_next   = (tlp_count_reg + pcie_addr_reg[1:0] - 1) >> $clog2(TLP_DATA_WIDTH_BYTES);
      last_next = cc_next == 0;
    end
  end

  always @(posedge clk) begin
    pcie_addr_reg <= pcie_addr;
    tlp_count_reg <= tlp_count;
    cc_reg        <= cc_next;
    last_reg      <= last_next;
  end

  assign cc   = cc_reg;
  assign last = last_reg;
endmodule
