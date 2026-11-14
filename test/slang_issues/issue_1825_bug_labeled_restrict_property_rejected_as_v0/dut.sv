// MikePopoloski/slang#1825 (closed): [bug] Labeled `restrict property` rejected as "expected a declaration name"
// https://github.com/MikePopoloski/slang/issues/1825
// Code block(s) from the issue (variant v0); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m(input logic clk, a);
  r1: restrict property (@(posedge clk) a);
endmodule

