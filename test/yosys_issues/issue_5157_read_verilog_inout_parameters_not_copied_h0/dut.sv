// YosysHQ/yosys#5157 (closed): `read_verilog`: `inout` parameters not copied out of tasks
// https://github.com/YosysHQ/yosys/issues/5157
// Code block(s) from the issue (variant h0); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top (
	output logic [7:0] out
);
	task automatic set_to_5(inout logic [7:0] val);
		val = 5;
	endtask

	always_comb begin
		out = 0;
		set_to_5(out);
	end

	always_comb assert(out == 5);
endmodule

