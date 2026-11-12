// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r27); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r27
// pr 268 try cause name conflict
module r27_submodule();
    always_comb begin
        foo: assert(1);
    end
endmodule

module r27();
    wire foo;
    r27_submodule bar();
endmodule

