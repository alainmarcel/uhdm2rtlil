// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r18); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r18
// return out of task
module r18(
    input logic [7:0] a, input logic [7:0] b, output logic [8:0] out
);
	task sum(logic [7:0] a, logic [7:0] b, output logic [8:0] out);
	    out = a + b;
	    return;
	endtask;
    always_comb sum(a, b, out);
endmodule

