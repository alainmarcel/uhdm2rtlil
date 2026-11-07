// YosysHQ/yosys#6305: unsized based literals wider than 32 bits are extended
// with their top bit by read_verilog instead of zeros.  `'h8_0000_0001` is a
// 36-bit unsigned literal and must zero-extend to 64'h0000_0008_0000_0001;
// `a & 'hff_ffff_ffff` masks to the low 40 bits.
module dut (input [63:0] a, output [63:0] y, output [63:0] z);
  assign y = 'h8_0000_0001;
  assign z = a & 'hff_ffff_ffff;
endmodule
