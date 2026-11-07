// YosysHQ/yosys#6085 (closed): cmp2lut mis-maps signed comparisons against negative constants
// https://github.com/YosysHQ/yosys/issues/6085
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top(input signed [3:0] a, output y);
    assign y = a >= -8;   // tautology for 4-bit signed a
endmodule

