// YosysHQ/yosys#6306 (open): read_verilog: packed struct array has the wrong width
// https://github.com/YosysHQ/yosys/issues/6306
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
typedef struct packed { logic [1:0] a; logic [1:0] b; } s_t;
module top(input s_t [3:0] x, output [15:0] q1, output [15:0] q2);
  s_t [3:0] t;
  assign t = 16'hffff;
  assign q1 = t;
  assign q2 = x;
endmodule

