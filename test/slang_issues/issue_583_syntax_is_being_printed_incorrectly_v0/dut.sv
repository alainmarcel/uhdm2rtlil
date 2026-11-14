// MikePopoloski/slang#583 (closed): Syntax is being printed incorrectly
// https://github.com/MikePopoloski/slang/issues/583
// Code block(s) from the issue (variant v0); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test_module (input logic a1, input logic a2, input logic a3, input logic a4, output logic y);
    assign y = a1 & a2 & a3 & a4;
endmodule

