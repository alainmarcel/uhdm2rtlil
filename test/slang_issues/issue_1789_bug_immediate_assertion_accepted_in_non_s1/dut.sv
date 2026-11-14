// MikePopoloski/slang#1789 (closed): [bug] Immediate assertion accepted in non-procedural context
// https://github.com/MikePopoloski/slang/issues/1789
// Code block(s) from the issue (variant s1); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m (input a, b);
  a1: assert #0 (a == b);
endmodule

