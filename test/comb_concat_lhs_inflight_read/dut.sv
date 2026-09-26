// A CONCAT-LHS blocking write inside a branch of a comb block, followed by a
// read of one of its parts in the same branch:
//   {ram_wrap_next, end_offset_next} = start + count - 1;
//   mask_next = 2'b11 >> (1 - (end_offset_next >> 5));
// (verilog-pcie dma_if_pcie_wr's RAM segment masks).  The in-flight value
// tracking bailed out on a multi-chunk LHS, so the read saw the STALE wire
// (last cycle's register) and the masks were wrong — the write DMA read the
// wrong RAM segments (275 co-sim divergences under a green seq-4 proof).
// Each full-wire chunk of a concat LHS now records its RHS slice.
module comb_concat_lhs_inflight_read (
  input  logic       clk,
  input  logic [5:0] s,
  input  logic [5:0] cbc,
  input  logic       go,
  output logic [1:0] m1,
  output logic [5:0] e,
  output logic       w
);
  reg [5:0] end_offset_reg = 0, end_offset_next;
  reg       ram_wrap_reg = 0, ram_wrap_next;
  reg [1:0] mask1_reg = 0, mask1_next;

  always @* begin
    end_offset_next = end_offset_reg;
    ram_wrap_next   = ram_wrap_reg;
    mask1_next      = mask1_reg;
    if (go) begin
      {ram_wrap_next, end_offset_next} = s + cbc - 1;
      mask1_next = {2{1'b1}} >> (2 - 1 - (end_offset_next >> 5));
    end
  end

  always @(posedge clk) begin
    end_offset_reg <= end_offset_next;
    ram_wrap_reg   <= ram_wrap_next;
    mask1_reg      <= mask1_next;
  end

  assign m1 = mask1_reg;
  assign e  = end_offset_reg;
  assign w  = ram_wrap_reg;
endmodule
