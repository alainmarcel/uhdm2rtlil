// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r4); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r4
module r4(input [1:0] s,
  output logic [63:0] __o_data);
	logic [1:0] [31:0] data;

	always_comb begin
		data = 0;
		for (int i = -10; i < 10; i++)
			data[s][i+:8] = 0;
	end

  // controllable/observable ports added by test/yosys_issues/observe.py
  assign __o_data = data;
endmodule

