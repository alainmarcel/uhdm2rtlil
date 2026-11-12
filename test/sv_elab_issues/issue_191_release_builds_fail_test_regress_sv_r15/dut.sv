// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r15); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r15
module r15sub(input [7:0] allbits, input [1:0] onebit, output bitout);
	assign bitout = allbits[onebit];
endmodule

module r15();
	wire [17:10] bitout;
	reg [7:0] allbits;
	reg [15:0] onebit;
	r15sub sub [7:0] (allbits, onebit, bitout);
endmodule

