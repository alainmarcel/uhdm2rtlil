// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r24); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r24
// test for an edge case from way back
module r24(input z, input [63:0] x);
	reg [31:0] y[0:0];

	always_comb begin
		y = '{0};
		for (int i = 0; i < 32; i++) begin
			if(~z) begin
			end else begin
				y[0][i] = x[2*i+1];
			end
		end
	end
endmodule

