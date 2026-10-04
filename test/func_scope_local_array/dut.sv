// A NON-ANSI function (its ports are `input` items, not a port list) declares
// unpacked array locals after them.  Surelog used to rebuild those locals from
// their data type alone and lose the unpacked dimension (`reg [63:0] tbl [0:3]`
// became a 64-bit logic_var); the reader, for its part, never declared
// function-scope locals at all -- only block-scope ones -- so every `tbl[i]`
// was a one-bit write and an empty read.  Both halves are needed for these
// values to come out right.  Each call is mixed with a port so the reader
// (not Surelog's own fold) evaluates it.
module dut (input [63:0] a, output [63:0] y0, output [63:0] y1, output [63:0] y2);
  function [63:0] xor_table;
    input [31:0] dummy;
    reg [63:0] tbl [0:3];
    integer i;
    begin
      tbl[0] = 64'h8000_0000_0000_0001; tbl[1] = 64'h0000_0001_0000_0000;
      tbl[2] = 64'h4000_0000_0000_0000; tbl[3] = 64'h0000_0000_8000_0000;
      xor_table = 0;
      for (i = 0; i < 4; i = i + 1) xor_table = xor_table ^ tbl[i];
    end
  endfunction
  function [63:0] shift_walk;     // element shifted in a loop, element compared
    input [31:0] dummy;
    reg [63:0] m [0:1];
    integer n;
    begin
      m[0] = {1'b1, {63{1'b0}}}; m[1] = 0; n = 0;
      while (m[0] != 0) begin
        m[1] = m[1] ^ (m[0] & 64'h5555_5555_5555_5555);
        m[0] = m[0] >> 1;
        n = n + 1;
      end
      shift_walk = m[1] ^ n;
    end
  endfunction
  function [63:0] accumulate;     // element read, element write, bit of an element
    input [31:0] dummy;
    reg [63:0] st [0:2];
    reg [63:0] v;
    integer j;
    begin
      st[0] = 64'h1; st[1] = 64'h2; st[2] = 64'h8000_0000_0000_0000; v = 0;
      for (j = 2; j >= 0; j = j - 1) begin v = st[j] ^ v; st[j] = v; end
      accumulate = st[0] ^ {st[2][63], 63'b0};
    end
  endfunction
  assign y0 = xor_table(0) ^ a;
  assign y1 = shift_walk(0) ^ a;
  assign y2 = accumulate(0) ^ a;
endmodule
