// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r25); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r25
// issue 247 bug in order_symbols_within_scope
module r25();
    r25_if foo ();
    r25_if bar ();

    always_comb begin
       foo.a = 0;
       bar.a = 1;
    end
endmodule

interface r25_if();
   logic a;
endinterface

