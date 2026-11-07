// YosysHQ/yosys#987 (closed): SystemVerilog var port kind
// https://github.com/YosysHQ/yosys/issues/987
// Code block(s) from the issue (variant v1); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module test(output var a, input b);
    always_comb a = b;
endmodule

