module gen_test8;

// `define VERIFY
`ifdef VERIFY
	`define ASSERT(expr) assert property (expr);
`else
	`define ASSERT(expr)
`endif

	wire [1:0] x = 2'b11;
	generate
		if (1) begin : A
			wire [1:0] x;
			if (1) begin : B
				wire [1:0] x = 2'b00;
				`ASSERT(x == 0)
				`ASSERT(A.x == 2)
				`ASSERT(A.C.x == 1)
				`ASSERT(A.B.x == 0)
				`ASSERT(gen_test8.x == 3)
				`ASSERT(gen_test8.A.x == 2)
				`ASSERT(gen_test8.A.C.x == 1)
				`ASSERT(gen_test8.A.B.x == 0)
			end
			if (1) begin : C
				wire [1:0] x = 2'b01;
				`ASSERT(x == 1)
				`ASSERT(A.x == 2)
				`ASSERT(A.C.x == 1)
				`ASSERT(A.B.x == 0)
				`ASSERT(gen_test8.x == 3)
				`ASSERT(gen_test8.A.x == 2)
				`ASSERT(gen_test8.A.C.x == 1)
				`ASSERT(gen_test8.A.B.x == 0)
			end
			assign x = B.x ^ 2'b11 ^ C.x;
			`ASSERT(x == 2)
			`ASSERT(A.x == 2)
			`ASSERT(A.C.x == 1)
			`ASSERT(A.B.x == 0)
			`ASSERT(gen_test8.x == 3)
			`ASSERT(gen_test8.A.x == 2)
			`ASSERT(gen_test8.A.C.x == 1)
			`ASSERT(gen_test8.A.B.x == 0)
		end
	endgenerate

	`ASSERT(x == 3)
	`ASSERT(A.x == 2)
	`ASSERT(A.C.x == 1)
	`ASSERT(A.B.x == 0)
	`ASSERT(gen_test8.x == 3)
	`ASSERT(gen_test8.A.x == 2)
	`ASSERT(gen_test8.A.C.x == 1)
	`ASSERT(gen_test8.A.B.x == 0)
endmodule
