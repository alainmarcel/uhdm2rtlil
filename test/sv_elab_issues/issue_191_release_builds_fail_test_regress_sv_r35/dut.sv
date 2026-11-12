// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r35); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r35
// issue 289 parameterized class function with different specializations
virtual class r35_cls #(parameter type type_t);
	static function func(input num);
		return 0;
	endfunction
endclass

module r35(output bit a, output logic b);
	assign a = r35_cls#(bit)::func(0);
	assign b = r35_cls#(logic)::func(0);
endmodule

