// MikePopoloski/slang#666 (closed): module XMR: using module name instead of instance name
// https://github.com/MikePopoloski/slang/issues/666
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top();
sub s();
initial begin
	sub.r[0:1]=1;
end
endmodule

module sub();
	reg[0:1]r;
	wire[0:1] b;
	assign b=r;
endmodule

