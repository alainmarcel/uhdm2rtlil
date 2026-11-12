// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r21); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r21
// $fatal with bad arg type
module r21(input clk);
    always @(posedge clk) begin
        // ... long procedure
        if (0)
        	$fatal("foo");
    end
endmodule

