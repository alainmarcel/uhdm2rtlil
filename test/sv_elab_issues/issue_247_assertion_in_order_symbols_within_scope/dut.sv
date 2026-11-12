// povik/sv-elab#247 (closed): Assertion in `order_symbols_within_scope` when working with multiple instances of interface
// https://github.com/povik/sv-elab/issues/247
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module repro_top ();
    foobar_if foo ();
    foobar_if bar ();

    always_comb begin
       foo.a = 0;
       bar.a = 1;
    end
endmodule

interface foobar_if ();
   logic  a;
endinterface

