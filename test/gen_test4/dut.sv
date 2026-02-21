module gen_test4(a, b);

input [3:0] a;
output [3:0] b;

genvar i;
generate
	for (i=0; i < 3; i=i+1) begin : foo
		localparam PREV = i - 1;
		wire temp;
		if (i == 0)
			assign temp = a[0];
		else
			assign temp = foo[PREV].temp & a[i];
		assign b[i] = temp;
	end
endgenerate
endmodule
