// MikePopoloski/slang#2006 (closed): Writes to two elements of a variable-size array conflict under always_comb
// https://github.com/MikePopoloski/slang/issues/2006
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__o_by_name, __o_dyn, __o_q);
  int by_name [string];
  int dyn [];
  int q [$];
  int fixed [4];

  always_comb by_name["out"] = 1;
  initial     by_name["in"]  = 4;

  always_comb dyn[1] = 1;
  initial     dyn[2] = 4;

  always_comb q[1] = 1;
  initial     q[2] = 4;

  always_comb fixed[1] = 1;
  initial     fixed[2] = 4;

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_by_name;
  assign __o_by_name = by_name;
  output logic __o_dyn;
  assign __o_dyn = dyn;
  output logic __o_q;
  assign __o_q = q;
endmodule

