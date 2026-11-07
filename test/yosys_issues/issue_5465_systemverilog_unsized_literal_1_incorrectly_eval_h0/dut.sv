// YosysHQ/yosys#5465 (closed): SystemVerilog unsized literal '1 incorrectly evaluated as 1-bit value instead of filling all bits
// https://github.com/YosysHQ/yosys/issues/5465
// Code block(s) from the issue (variant h0); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top (
    output logic [3:0] o
);
   localparam logic [3:0] L1 = '1;
   assign o = L1;
   always_comb assert(o == 4'b1111);
endmodule

