// A constant function evaluated by the reader at compile time: its bitwise
// and relational operators must run at the operands' full width.  They used
// to run at 32 bits, so verilog-ethernet's lfsr_mask never entered its
// `for (data_mask = {1'b1, {63{1'b0}}}; data_mask != 0; ...)` walk and every
// 58-bit XOR between mask-table entries lost its upper bits.
module dut (input [63:0] a, output [63:0] y0, output [57:0] y1, output [63:0] y2, output [7:0] y3);
  // the loop guard compares a 64-bit value whose only set bit is bit 63
  function [63:0] walk(input [31:0] dummy);
    reg [63:0] mask; reg [63:0] acc; integer n;
    begin
      acc = 0; n = 0;
      for (mask = {1'b1, {63{1'b0}}}; mask != 0; mask = mask >> 1) begin
        acc = acc ^ (mask & 64'h5555_5555_5555_5555);
        n = n + 1;
      end
      walk = acc ^ n;
    end
  endfunction
  // bits above 31 of an XOR between two 58-bit table entries
  function [57:0] mix58(input [31:0] dummy);
    reg [57:0] st [0:1];
    begin
      st[0] = 58'h200_0000_0000_0001; st[1] = 58'h100_0000_0000_0000;
      mix58 = st[0] ^ st[1];
    end
  endfunction
  // relational operators on a 64-bit value with nothing in its low word
  function [63:0] cmp64(input [31:0] dummy);
    reg [63:0] v;
    begin
      v = 64'h1_0000_0000;
      cmp64 = 0;
      if (v > 64'd1) cmp64[0] = 1'b1;
      if (v != 0) cmp64[1] = 1'b1;
      if (v == 64'h1_0000_0000) cmp64[2] = 1'b1;
      if ((v | 64'h1) == 64'h1_0000_0001) cmp64[3] = 1'b1;
      if (v >= 64'h1_0000_0000) cmp64[4] = 1'b1;
      if (64'd1 < v) cmp64[5] = 1'b1;
      if ((v & 64'hFFFF_FFFF) == 0) cmp64[6] = 1'b1;
    end
  endfunction
  // a signed integer loop guard must keep terminating on -1
  function [7:0] desc(input [31:0] dummy);
    integer i;
    begin
      desc = 0;
      for (i = 3; i >= 0; i = i - 1) desc = desc + 1;
    end
  endfunction
  // Each call is mixed with a port so that it reaches the reader's evaluator:
  // Surelog folds a call that is the whole RHS (or a localparam) itself, and
  // its own evaluator has its own array-element bugs (not this test's subject).
  assign y0 = walk(0) ^ a;
  assign y1 = mix58(0) ^ a[57:0];
  assign y2 = cmp64(0) ^ a;
  assign y3 = desc(0) ^ a[7:0];
endmodule
