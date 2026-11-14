// MikePopoloski/slang#477 (closed): parse error for a package enum label and cover-property label name-clash
// https://github.com/MikePopoloski/slang/issues/477
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
package pkg;
    typedef enum logic[6:0] {
        OP_A = 7'b10_00100
    } opcode_t;
endpackage

module m
    import pkg::*;
(
    input logic       clk,
    input logic [6:0] op
);
    OP_A: cover property( @(posedge clk) op == OP_A);
endmodule

