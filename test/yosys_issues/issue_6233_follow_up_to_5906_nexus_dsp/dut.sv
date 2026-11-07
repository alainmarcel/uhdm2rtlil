// YosysHQ/yosys#6233 (closed): Follow up to #5906 Nexus DSP - infer two more MAC shapes
// https://github.com/YosysHQ/yosys/issues/6233
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module mac36 (
    input  [35:0]  a, b,
    input  [107:0] c,
    output [107:0] y
);
    assign y = c + a * b;
endmodule

// ---- b1.sv
module dot4_acc (
    input  [8:0]  a0, b0, a1, b1, a2, b2, a3, b3,
    input  [53:0] c,
    output [53:0] y
);
    assign y = a0*b0 + a1*b1 + a2*b2 + a3*b3 + c;
endmodule

