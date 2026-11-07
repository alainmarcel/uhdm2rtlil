// YosysHQ/yosys#6306: a packed array of a packed struct (`s_t [3:0]`) lost
// its array dimension in read_verilog and became a 4-bit wire.  Each s_t is
// 4 bits, so the port and the local are 16 bits wide: `t = 16'hffff` reads
// back whole, and the port passes all 16 bits through.
typedef struct packed { logic [1:0] a; logic [1:0] b; } s_t;
module dut (input s_t [3:0] x, output [15:0] q1, output [15:0] q2, output [3:0] q3);
  s_t [3:0] t;
  assign t = 16'hffff;
  assign q1 = t;
  assign q2 = x;
  assign q3 = x[2];           // element 2: bits [11:8]
endmodule
