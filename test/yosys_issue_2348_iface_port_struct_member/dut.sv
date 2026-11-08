// YosysHQ/yosys#2348: a packed-struct member of an interface, read field by
// field through an interface PORT (`w.b.foo`).  Surelog's port-side
// interface_inst omits the struct member, so the reader never recorded its
// struct typespec and every field read came out as a constant X.
typedef struct packed {
	logic [3:0] foo;
	logic [1:0] bar;
} st;

interface wrapper;
	st b;
	logic [2:0] c;
endinterface

module baz (wrapper w, output wire [3:0] qux, output wire [1:0] q2,
            output wire [2:0] q3);
	assign qux = w.b.foo;
	assign q2  = w.b.bar;
	assign q3  = w.c;
endmodule

module dut (input [5:0] d, input [2:0] e, output [3:0] qux,
            output [1:0] q2, output [2:0] q3);
	wrapper w();
	assign w.b = d;
	assign w.c = e;
	baz u (.w(w), .qux(qux), .q2(q2), .q3(q3));
endmodule
