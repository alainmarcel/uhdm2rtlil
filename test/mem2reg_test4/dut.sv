module mem2reg_test4(result1, result2, result3);
	output signed [9:0] result1;
	output signed [9:0] result2;
	output signed [9:0] result3;

	wire signed [9:0] intermediate [0:3];

	function integer depth2Index;
		input integer depth;
		depth2Index = depth;
	endfunction

	assign intermediate[depth2Index(1)] = 1;
	assign intermediate[depth2Index(2)] = 2;
	assign intermediate[3] = 3;
	assign result1 = intermediate[1];
	assign result2 = intermediate[depth2Index(2)];
	assign result3 = intermediate[depth2Index(3)];
endmodule
