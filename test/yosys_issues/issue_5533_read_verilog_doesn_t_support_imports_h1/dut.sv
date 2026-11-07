// YosysHQ/yosys#5533 (open): read_verilog doesn't support imports in packages
// https://github.com/YosysHQ/yosys/issues/5533
// Code block(s) from the issue (variant h1); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
package types;
typedef logic yn_t;
endpackage

module top (input types::yn_t d, output types::yn_t q);
endmodule

