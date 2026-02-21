module gen_test2(clk, a, b, y);

input clk;
input [7:0] a, b;
output reg [8:0] y;

integer i;
reg [8:0] carry;

always @(posedge clk) begin
	carry[0] = 0;
	for (i = 0; i < 8; i = i + 1) begin
		casez ({a[i], b[i], carry[i]})
			3'b?11, 3'b1?1, 3'b11?:
				carry[i+1] = 1;
			default:
				carry[i+1] = 0;
		endcase
		y[i] = a[i] ^ b[i] ^ carry[i];
	end
	y[8] = carry[8];
end

endmodule
