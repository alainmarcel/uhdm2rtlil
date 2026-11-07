// YosysHQ/yosys#4006 (closed): Import package error
// https://github.com/YosysHQ/yosys/issues/4006
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
package my_pkg;
    localparam NUM = 1;
endpackage

// ---- b1.sv
module test1 import my_pkg::*; (
    input a,
    output b
);
    assign b = (a ^ NUM);
endmodule

// ---- b2.sv
module test2 (
    input a,
    output b
);
    import my_pkg::*;
    assign b = (a ^ NUM);
endmodule

