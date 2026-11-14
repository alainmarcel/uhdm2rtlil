// povik/sv-elab#181 (closed): Should `real` values be synthesizable?
// https://github.com/povik/sv-elab/issues/181
// Code block(s) from the issue (variant v1); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module a (input real a1);
endmodule: a

module b(__i_b1);
  a a_inst(.a1(b1));

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_b1;
  assign b1 = __i_b1;
endmodule: b

