// YosysHQ/yosys#3773 (open): Yosys synthesis breaks CPU functionality
// https://github.com/YosysHQ/yosys/issues/3773
// Code block(s) from the issue (variant v0); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module tiny_top (
        result_o
);
  output wire [63:0] result_o;
        assign result_o = 2 ** (52 - 1);
endmodule

