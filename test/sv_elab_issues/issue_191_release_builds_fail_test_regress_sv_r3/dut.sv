// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r3); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r3
module r3 (__o_m);
logic [7:0] m;
always @(*) begin
	m[4-:2] <= 0;
end

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic [7:0] __o_m;
  assign __o_m = m;
endmodule

