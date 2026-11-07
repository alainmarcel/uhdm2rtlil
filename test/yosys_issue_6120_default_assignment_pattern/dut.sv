// YosysHQ/yosys#6120: `'{default: ...}` is a syntax error in read_verilog -sv.
// LRM 10.9.1: the default key fills every element.  Unpacked, packed and a
// declaration initialiser, with a non-zero default so a dropped pattern shows.
module dut (input logic [31:0] d, output logic [31:0] q, output logic [31:0] p2, output logic [7:0] i1);
  logic [31:0] m [0:3];
  assign m = '{default: 32'h0};
  assign q = m[0] ^ d;
  logic [3:0][31:0] p;
  assign p = '{default: 32'h1234_5678};
  assign p2 = p[2];
  logic [1:0][7:0] ini = '{default: 8'hA5};
  assign i1 = ini[1];
endmodule
