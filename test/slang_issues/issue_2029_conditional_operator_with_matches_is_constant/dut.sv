// MikePopoloski/slang#2029 (closed): Conditional operator with `matches` is constant-folded when the matched expression is not constant
// https://github.com/MikePopoloski/slang/issues/2029
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top;
  int x = 5;
  logic z1, z2, z3;
  assign z1 = x matches 5 ? 0 : 2;
  assign z2 = (x == 5) ? 0 : 2;
  initial z3 = x matches 5 ? 0 : 2;
endmodule

