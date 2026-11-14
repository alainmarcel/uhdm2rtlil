// povik/sv-elab#128 (closed): [bug] Hierarchical references issues
// https://github.com/povik/sv-elab/issues/128
// Code block(s) from the issue (variant v2); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top(__o_t);

wire t;

n n1();
assign t = n1.n;



  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_t;
  assign __o_t = t;
endmodule

module n();
wire n;
endmodule

