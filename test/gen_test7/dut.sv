module gen_test7;
	reg [2:0] out1;
	reg [2:0] out2;
	wire [2:0] out3;
	generate
		if (1) begin : cond
			reg [2:0] sub_out1;
			reg [2:0] sub_out2;
			wire [2:0] sub_out3;
			initial begin : init
				reg signed [31:0] x;
				x = 2 ** 2;
				out1 = x;
				sub_out1 = x;
			end
			always @* begin : proc
				reg signed [31:0] x;
				x = 2 ** 1;
				out2 = x;
				sub_out2 = x;
			end
			genvar x;
			for (x = 0; x < 3; x = x + 1) begin
				assign out3[x] = 1;
				assign sub_out3[x] = 1;
			end
		end
	endgenerate

// `define VERIFY
`ifdef VERIFY
	assert property (out1 == 4);
	assert property (out2 == 2);
	assert property (out3 == 7);
	assert property (cond.sub_out1 == 4);
	assert property (cond.sub_out2 == 2);
	assert property (cond.sub_out3 == 7);
`endif
endmodule
