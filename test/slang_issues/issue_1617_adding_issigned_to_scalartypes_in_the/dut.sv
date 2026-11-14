// MikePopoloski/slang#1617 (closed): Adding "isSigned" to ScalarTypes in the AST JSON.
// https://github.com/MikePopoloski/slang/issues/1617
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module abc(
   input logic signed [4:0] a,
   output logic signed [4:0] b
);
   assign b = a;
endmodule : abc

