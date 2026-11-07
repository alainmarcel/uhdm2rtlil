// YosysHQ/yosys#3278 (open): Synthesis issue with shift (likely `alumacc`)
// https://github.com/YosysHQ/yosys/issues/3278
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- c0.sv
module top(
    output wire [4:0] out,
    input wire signed [3:0] inp1,
    input wire [3:0] inp2
);
    assign out = -$signed(-(inp1 << inp2));
endmodule

// ---- c1.sv
module t(input signed [4:0] a, output [15:0] y);
  assign y = -($signed(5'(-a)));
endmodule

