// A generate-loop CONTINUOUS assign to an element bit of a MODULE-level net array
// (OpenPiton oled_transform's glyph transpose: `assign char_cell[i][j] =
// char_map[j][i];`), read with a dynamic index in an always block.  The dynamic
// read made the array a $mem and every assign became a memory READ driving its
// data wire, so nothing wrote the memory and the registered read stayed 0.
module dut(input clk, input [15:0] d, input [1:0] sel, output reg [3:0] q, output [3:0] c1);
  wire [3:0] m [3:0];
  wire [3:0] cc [3:0];
  assign {m[0], m[1], m[2], m[3]} = d;
  generate begin
    genvar i, j;
    for (i = 0; i < 4; i = i + 1) begin: col
      for (j = 0; j < 4; j = j + 1) begin: row
        assign cc[i][j] = m[j][i];
      end
    end
  end
  endgenerate
  always @(posedge clk) q <= cc[sel];
  assign c1 = cc[1];
endmodule
