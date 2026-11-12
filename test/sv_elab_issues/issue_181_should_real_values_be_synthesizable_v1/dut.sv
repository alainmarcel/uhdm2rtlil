// povik/sv-elab#181 (closed): Should `real` values be synthesizable?
// https://github.com/povik/sv-elab/issues/181
// Code block(s) from the issue (variant v1); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module a (input real a1);
endmodule: a

module b();
  a a_inst(.a1(b1));
endmodule: b

