module top (
	input  clk,
	input  a, b,
	// Outputs exposing the internal state monitored by the asserts —
	// the asserts check temporal properties of `b`, so capture `b`
	// into a register and forward both that and the raw input.  Gives
	// the co-sim an observable signal that exercises the clocked path.
	output logic b_o,
	output logic b_prev_o
);
	default clocking @(posedge clk); endclocking

	logic b_prev = 0;
	always @(posedge clk) b_prev <= b;

	assign b_o      = b;
	assign b_prev_o = b_prev;

`ifndef VERILATOR
	// Skip the SVA assertion in Verilator co-sim: our random testbench
	// doesn't guarantee `$changed(b)` is true every cycle, and the
	// property is the subject of the SVA-support test rather than a
	// semantic guarantee we want to enforce in simulation.
	assert property (
		$changed(b)
	);
`endif

	wire x = 'x;

`ifndef FAIL
`ifndef VERILATOR
	// Verilator 5.x trips over `!== x ##1 ...` in this assume expression
	// (sequence-precedence ambiguity); ifdef it out of the sim-equiv
	// build but keep it for synth — the assert above remains the actual
	// test of SVA $changed support.
	assume property (
		b !== x ##1 $changed(b)
	);
`endif
`endif

endmodule
