module top (
	input  logic clock, ctrl,
	// Outputs exposing the internal states the bound properties
	// module monitors — without them the DUT is purely self-checking
	// and there's nothing for an external co-simulator to compare.
	output logic read_o, write_o, ready_o
);
	logic read = 0, write = 0, ready = 0;

	always @(posedge clock) begin
		read <= !ctrl;
		write <= ctrl;
		ready <= write;
	end

	assign read_o  = read;
	assign write_o = write;
	assign ready_o = ready;
endmodule

module top_properties (input logic clock, read, write, ready);
	a_rw: assert property ( @(posedge clock) !(read && write) );
`ifdef FAIL
	a_wr: assert property ( @(posedge clock) write |-> ready );
`else
	a_wr: assert property ( @(posedge clock) write |=> ready );
`endif
endmodule

bind top top_properties properties_inst (.*);
