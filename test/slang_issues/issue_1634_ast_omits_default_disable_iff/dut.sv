// MikePopoloski/slang#1634 (closed): AST omits default disable iff
// https://github.com/MikePopoloski/slang/issues/1634
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test_disable (input logic a, b, rst, clk);
    default clocking cb @(posedge clk); endclocking
    default disable iff (rst);
    a1 : assert property ( a |=> b );
endmodule

