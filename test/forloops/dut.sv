module forloops (input clk, a, b, output reg [3:0] p, q, x, y);
	integer k;
	always @(posedge clk) begin
		for (k=0; k<2; k=k+1)
			p[2*k +: 2] = {a, b} ^ {2{k}};
		x <= k + {a, b};
	end
	always @* begin
		for (k=0; k<4; k=k+1)
			q[k] = {~a, ~b, a, b} >> k[1:0];
		y = k - {a, b};
	end
endmodule