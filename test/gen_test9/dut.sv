module gen_test9;

// `define VERIFY
`ifdef VERIFY
	`define ASSERT(expr) assert property (expr);
`else
	`define ASSERT(expr)
`endif

	wire [1:0] w = 2'b11;
	generate
		begin : A
			wire [1:0] x;
			begin : B
				wire [1:0] y = 2'b00;
				`ASSERT(w == 3)
				`ASSERT(x == 2)
				`ASSERT(y == 0)
				`ASSERT(A.x == 2)
				`ASSERT(A.C.z == 1)
				`ASSERT(A.B.y == 0)
				`ASSERT(gen_test9.w == 3)
				`ASSERT(gen_test9.A.x == 2)
				`ASSERT(gen_test9.A.C.z == 1)
				`ASSERT(gen_test9.A.B.y == 0)
			end
			begin : C
				wire [1:0] z = 2'b01;
				`ASSERT(w == 3)
				`ASSERT(x == 2)
				`ASSERT(z == 1)
				`ASSERT(A.x == 2)
				`ASSERT(A.C.z == 1)
				`ASSERT(A.B.y == 0)
				`ASSERT(gen_test9.w == 3)
				`ASSERT(gen_test9.A.x == 2)
				`ASSERT(gen_test9.A.C.z == 1)
				`ASSERT(gen_test9.A.B.y == 0)
			end
			assign x = B.y ^ 2'b11 ^ C.z;
			`ASSERT(x == 2)
			`ASSERT(A.x == 2)
			`ASSERT(A.C.z == 1)
			`ASSERT(A.B.y == 0)
			`ASSERT(gen_test9.w == 3)
			`ASSERT(gen_test9.A.x == 2)
			`ASSERT(gen_test9.A.C.z == 1)
			`ASSERT(gen_test9.A.B.y == 0)
		end
	endgenerate

	`ASSERT(w == 3)
	`ASSERT(A.x == 2)
	`ASSERT(A.C.z == 1)
	`ASSERT(A.B.y == 0)
	`ASSERT(gen_test9.w == 3)
	`ASSERT(gen_test9.A.x == 2)
	`ASSERT(gen_test9.A.C.z == 1)
	`ASSERT(gen_test9.A.B.y == 0)
endmodule
