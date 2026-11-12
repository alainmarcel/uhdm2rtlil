// povik/sv-elab#222 (closed): Conflicting init values for signal during OPT pass
// https://github.com/povik/sv-elab/issues/222
// Code block(s) from the issue (variant s0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module a(output bit [1:4] w1, input bit w2);

  not not1(w3, w4);
  not not2(w5, w2);

  assign w4 = w2;
  assign w3 = w1;
endmodule: a

