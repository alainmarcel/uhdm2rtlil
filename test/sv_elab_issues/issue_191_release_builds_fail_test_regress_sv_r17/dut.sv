// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r17); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r17
// false memory inference on function argument
module r17();
	function f(int arg [1:0]);
	endfunction
	always_comb begin
		int v [1:0];
		f(v);
	end
endmodule

