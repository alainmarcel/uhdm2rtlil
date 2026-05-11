module top (input logic clk, input logic selA, selB, QA, QB, output logic Q);
	always @(posedge clk) begin
		if (selA) Q <= QA;
		if (selB) Q <= QB;
	end

`ifndef VERILATOR
	// The assumes/asserts impose that selA and selB are not both high;
	// the random co-sim stimulus doesn't honour that, so ifdef the SVA
	// out of Verilator's build (the test of SVA $past/|=> support is
	// the synth path, not co-sim).
	check_selA: assert property ( @(posedge clk) selA |=> Q == $past(QA) );
	check_selB: assert property ( @(posedge clk) selB |=> Q == $past(QB) );
`ifndef FAIL
	assume_not_11: assume property ( @(posedge clk) !(selA & selB) );
`endif
`endif
endmodule
