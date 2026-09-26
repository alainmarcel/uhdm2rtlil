// Arithmetic operators are context-determined (LRM 11.6.1): every operand
// of `(cnt + addr[4:2] - 1) >> 3` is evaluated at the width of the WHOLE
// expression -- max(8-bit LHS, 10-bit cnt, 3-bit slice, 32-bit `1`) = 32 --
// and only the final assignment truncates.  read_uhdm sized the nested
// `cnt + addr[4:2]` from its own operands plus the 8-bit LHS context, so the
// 10-bit sum wrapped BEFORE the `- 1` and the shift: verilog-pcie
// pcie_us_axi_master_wr's burst length came out 255 instead of 127 (formal
// counterexample with defined inputs; random co-sim never hit it).
// `len_wide` is the 13-bit twin whose wrap falls outside the 8-bit result.
module arith_context_width_nested_add (
  input  logic [9:0]  cnt,
  input  logic [12:0] cnt_wide,
  input  logic [63:0] addr,
  input  logic        sel,
  output logic [7:0]  len,
  output logic [7:0]  len_assign,
  output logic [7:0]  len_wide
);
  localparam OFFSET_WIDTH   = 3;
  localparam AXI_BURST_SIZE = 5;
  reg [9:0]  cnt_next;
  reg [63:0] addr_next;
  always @* begin
    cnt_next  = cnt;
    addr_next = addr;
    len = 8'd0;
    if (sel) begin
      cnt_next = cnt + 1;
      len = (cnt_next + addr_next[OFFSET_WIDTH+2-1:2] - 1) >> (AXI_BURST_SIZE-2);
    end
  end
  assign len_assign = (cnt + addr[OFFSET_WIDTH+2-1:2] - 1) >> (AXI_BURST_SIZE-2);
  assign len_wide   = (cnt_wide + addr[OFFSET_WIDTH+2-1:2] - 1) >> (AXI_BURST_SIZE-2);
endmodule
