// Top wrapper: instantiate both for-loop modules and promote every port of
// each instance to a distinct top-level port, so both modules survive
// synthesis and are independently controllable/observable.
module simple_forloops (
	input        clk,
	input        a1, b1,
	output [3:0] p1, q1, x1, y1,
	input        a2, b2,
	output [3:0] q2, x2, y2
);
	forloops01 u1 (.clk(clk), .a(a1), .b(b1), .p(p1), .q(q1), .x(x1), .y(y1));
	forloops02 u2 (.clk(clk), .a(a2), .b(b2), .q(q2), .x(x2), .y(y2));
endmodule

module forloops01 (input clk, a, b, output reg [3:0] p, q, x, y);
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

module forloops02 (input clk, a, b, output reg [3:0] q, x, output [3:0] y);
	integer k;
	always @* begin
		for (k=0; k<4; k=k+1)
			q[k] = {~a, ~b, a, b} >> k[1:0];
	end
	always @* begin
		x = k + {a, b};
	end
	assign y = k - {a, b};
endmodule
