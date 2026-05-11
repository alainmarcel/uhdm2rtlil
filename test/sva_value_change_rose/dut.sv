module top (
	input  clk,
	input  a, b,
	// Outputs exposing internal states the asserts monitor — `a_copy`
	// (the alias the SVA `$rose` uses) and clocked snapshots of a/b.
	output       a_copy_o,
	output logic a_q_o,
	output logic b_q_o
);
	default clocking @(posedge clk); endclocking

    wire a_copy;
    assign a_copy = a;

	logic a_q = 0, b_q = 0;
	always @(posedge clk) begin
		a_q <= a;
		b_q <= b;
	end
	assign a_copy_o = a_copy;
	assign a_q_o    = a_q;
	assign b_q_o    = b_q;

`ifndef VERILATOR
	assert property (
		$rose(a) |-> b
	);

`ifndef FAIL
	assume property (
		$rose(a_copy) |-> b
	);
`endif
`endif

endmodule
