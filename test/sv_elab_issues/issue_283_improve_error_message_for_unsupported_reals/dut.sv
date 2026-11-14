// povik/sv-elab#283 (open): Improve error message for unsupported reals
// https://github.com/povik/sv-elab/issues/283
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module a (input real a1);
endmodule: a

module b(__i_b1);
  a a_inst(.a1(b1));

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_b1;
  assign b1 = __i_b1;
endmodule: b

