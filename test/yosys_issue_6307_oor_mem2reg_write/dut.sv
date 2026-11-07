// YosysHQ/yosys#6307: an out-of-range write to an array that mem2reg turns into
// registers wrapped around and overwrote a valid entry (`r[4]` landed on r[0],
// `r[5]` on r[1]).  LRM 7.4.6: a write outside the declared range has no
// effect, so z0 / z1 keep 1 / 2 for a = 4 and a = 5; in range the write lands.
module dut (input [2:0] a, output reg [3:0] z0, output reg [3:0] z1);
  reg [3:0] r [0:3];
  always @* begin
    r[0] = 4'h1; r[1] = 4'h2; r[2] = 4'h3; r[3] = 4'h4;
    r[a] = 4'h7;
    z0 = r[0]; z1 = r[1];
  end
endmodule
