// YosysHQ/yosys#6346: an unsized based literal with bit 31 set is sign-extended
// / 33 bits wide by read_verilog.  `'h80000000` is an UNSIGNED 32-bit literal:
// in a 40-bit context it is 40'h00_8000_0000, `'d4294967295` is
// 40'h00_FFFF_FFFF, and a parameter initialised from `'hFFFFFFFF` holds the
// same.  The SIGNED forms behave as 32-bit two's complement: `'shFFFFFFFF`
// equals -1 and is negative, and `'sh80000000` assigned to a signed 40-bit
// wire sign-extends to 40'hFF_8000_0000.
module dut (
  output [39:0] y, z, w,
  output y1, y2,
  output signed [39:0] ws
);
  parameter [39:0] P = 'hFFFFFFFF;
  assign y = P;
  assign z = 'h80000000;
  assign w = 'd4294967295;
  assign y1 = ('shFFFFFFFF == -1);
  assign y2 = ('shFFFFFFFF < 0);
  wire signed [39:0] ww = 'sh80000000;
  assign ws = ww;
endmodule
