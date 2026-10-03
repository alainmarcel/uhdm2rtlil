// A shift AMOUNT is self-determined (LRM 11.6.1): the assignment's 64-bit
// context must not reach `~(a[4:0])` or `5'(a) + 5'h3`.  Imported under the
// context width, the 5-bit slice was zero-extended to 64 bits BEFORE the NOT
// (amount 2^64-32+x -> result 0): XiangShan ICacheMainPipe's aligned RVC map
// `{31'h0, map, 1'h0} << ~(vAddr[4:0])` was 0 in 153 of 301 cycles.
// Self-determined is the amount's OWN width, not none: in
// `be << (addr & ({1{1'b1}} << 3))` (verilog-pcie dma_client_axis_sink) the
// 16-bit `&` sizes the inner `1'b1 << 3` to 16 bits (= 8); evaluated at its
// 1-bit operand width it is 0 and every byte enable lands in the wrong lane.
module dut(input [31:0] m, input [7:0] a, input [4:0] b,
           input [15:0] addr, input [15:0] be,
           output [63:0] y0, output [63:0] y1, output [62:0] y2, output [63:0] y3, output [15:0] y4);
  assign y0 = {31'h0, m, 1'h0} << ~(a[4:0]);
  assign y1 = {31'h0, m, 1'h0} << ~b;
  assign y2 = {31'h0, m} << (5'(a) + 5'h3);
  assign y3 = {32'h0, m} >> ~b;
  assign y4 = be << (addr & ({1{1'b1}} << 3));
endmodule
