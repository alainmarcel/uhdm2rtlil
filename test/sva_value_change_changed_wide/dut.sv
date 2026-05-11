module top (
	input  clk,
	input  [2:0] a,
	input  [2:0] b,
	// Outputs exposing the inputs the asserts monitor — flop'd through
	// `clk` so the co-sim exercises a clocked path between the SV and
	// netlist forms.
	output logic [2:0] a_o,
	output logic [2:0] b_o
);
	default clocking @(posedge clk); endclocking

	logic [2:0] a_q = 0, b_q = 0;
	always @(posedge clk) begin
		a_q <= a;
		b_q <= b;
	end
	assign a_o = a_q;
	assign b_o = b_q;

`ifndef VERILATOR
	// SVA assertions: not driven by the random co-sim stimulus, so
	// ifdef them out of Verilator's parse — keep them for synth.
	assert property (
		$changed(a)
	);

    assert property (
        $changed(b) == ($changed(b[0]) || $changed(b[1]) || $changed(b[2]))
    );

`ifndef FAIL
	assume property (
		a !== 'x ##1 $changed(a)
	);
`endif
`endif

endmodule
