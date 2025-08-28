module gen_test1(clk, a, b, y);

input clk;
input [7:0] a, b;
output reg [7:0] y;

genvar i, j;
wire [15:0] tmp1;

generate

	for (i = 0; i < 8; i = i + 1) begin:gen1
		wire and_wire, or_wire;
		assign and_wire = a[i] & b[i];
		assign or_wire = a[i] | b[i];
		if (i % 2 == 0) begin:gen2true
			assign tmp1[i] = and_wire;
			assign tmp1[i+8] = or_wire;
		end else begin:gen2false
			assign tmp1[i] = or_wire;
			assign tmp1[i+8] = and_wire;
		end
	end

	for (i = 0; i < 8; i = i + 1) begin:gen3
		wire [4:0] tmp2;
		for (j = 0; j <= 4; j = j + 1) begin:gen4
			wire tmpbuf;
			assign tmpbuf = tmp1[i+2*j];
			assign tmp2[j] = tmpbuf;
		end
		always @(posedge clk)
			y[i] <= ^tmp2;
	end

endgenerate

endmodule