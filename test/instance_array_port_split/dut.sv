// povik/sv-elab tests/various/regress.sv r15: an instance array whose
// actuals are split by PORT width (LRM 23.3.3.5).  `allbits` (8 bits, port
// 8) goes WHOLE to every member; `onebit` (16 bits, port 2) gives member k
// bits [2k+1:2k]; `bitout[17:10]` (port 1) gives member k bit 10+k.  Surelog
// used to hand each member bit <index> of every actual -- 1 bit of allbits,
// 1 bit of onebit, and an out-of-range bit of bitout -- and read_uhdm
// connected `1'x`.  `m2` is a 2-D instance array over a 1-bit port.
module sub(input [7:0] allbits, input [1:0] onebit, output bitout);
  assign bitout = allbits[onebit];
endmodule
module inv(input a, output y);
  assign y = ~a;
endmodule
module top(input [7:0] allbits, input [15:0] onebit, output [17:10] bitout,
           input [5:0] a2, output [5:0] y2);
  sub s [7:0] (allbits, onebit, bitout);
  inv m2 [1:0][2:0] (a2, y2);
endmodule
