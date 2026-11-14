// MikePopoloski/slang#2029 (closed): Conditional operator with `matches` is constant-folded when the matched expression is not constant
// https://github.com/MikePopoloski/slang/issues/2029
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__o_z1, __o_z2, __o_z3);
  int x = 5;
  logic z1, z2, z3;
  assign z1 = x matches 5 ? 0 : 2;
  assign z2 = (x == 5) ? 0 : 2;
  initial z3 = x matches 5 ? 0 : 2;

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_z1;
  assign __o_z1 = z1;
  output logic __o_z2;
  assign __o_z2 = z2;
  output logic __o_z3;
  assign __o_z3 = z3;
endmodule

