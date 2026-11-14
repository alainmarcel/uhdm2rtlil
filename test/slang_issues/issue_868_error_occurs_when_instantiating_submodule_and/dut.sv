// MikePopoloski/slang#868 (closed): Error occurs when instantiating submodule and passing parameters without using parentheses
// https://github.com/MikePopoloski/slang/issues/868
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module a (i0, i1, o1);
parameter B_SIZE = 8;
input [B_SIZE-1:0] i0;
input [B_SIZE-1:0] i1;
output [B_SIZE-1:0] o1;

assign o1[B_SIZE-1:0] = i0[B_SIZE-1:0] + i1[B_SIZE-1:0];
endmodule

module b(i0, i1, o1);
input [65:0] i0;
input [65:0] i1;
output [65:0] o1;

a #66 new_adder(.i0 (i0 ), .i1(i1 ), .o1(o1 ));

endmodule

