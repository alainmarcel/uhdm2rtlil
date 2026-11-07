// YosysHQ/yosys#4263 (open): AST fails to handle implicit wires properly
// https://github.com/YosysHQ/yosys/issues/4263
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module gold(a, b);
	output wire [1:0] a;
	input wire [1:0] b;
	genvar i;
	for (i = 0; i < 2; i++) begin
		wire x;
		assign x = b[i];
		assign a[i] = x;
	end
endmodule

module gate(a, b);
	output wire [1:0] a;
	input wire [1:0] b;
	genvar i;
	for (i = 0; i < 2; i++) begin
		assign x = b[i];
		assign a[i] = x;
	end
endmodule

