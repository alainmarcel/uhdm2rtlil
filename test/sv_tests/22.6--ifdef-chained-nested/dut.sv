// Converted from chipsalliance/sv-tests (22.6--ifdef-chained-nested, :type: preprocessing).
// Upstream marks each `ifdef arm with a $display, which synthesis cannot see, so
// nothing checks WHICH arm the chain selected.  The arm structure is kept
// VERBATIM and each arm now assigns a distinct code to a real output, so the
// selection is read back as a value.
// Upstream kept as orig.sv.
module test(input logic b, input logic c, output logic [3:0] arm, output logic o);
`ifdef first_block
	`ifndef second_nest
		assign arm = 4'd1;
	`else
		assign arm = 4'd2;
	`endif
`elsif second_block
	assign arm = 4'd3;
`else
	`ifndef last_result
		assign arm = 4'd4;
	`elsif real_last
		assign arm = 4'd5;
	`else
		assign arm = 4'd6;
	`endif
`endif
	assign o = b & c;
endmodule
