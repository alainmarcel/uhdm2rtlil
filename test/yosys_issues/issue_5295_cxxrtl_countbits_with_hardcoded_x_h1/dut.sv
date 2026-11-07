// YosysHQ/yosys#5295 (closed): cxxrtl countbits with hardcoded `x`
// https://github.com/YosysHQ/yosys/issues/5295
// Code block(s) from the issue (variant h1); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module countbits (
    input logic [7:0] in_d,
    output logic [3:0] cnt
);
    assign cnt = $countbits(in_d, 1'b1, 1'bx);
endmodule

