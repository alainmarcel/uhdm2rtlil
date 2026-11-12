// povik/sv-elab#286 (open): Less padding in multiplication operands
// https://github.com/povik/sv-elab/issues/286
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module test (
    input  [1:0] a,
    input  [1:0] b,
    output [3:0] e
);
    assign e = a * b;
endmodule

