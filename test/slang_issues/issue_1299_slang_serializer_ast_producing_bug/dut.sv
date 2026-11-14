// MikePopoloski/slang#1299 (closed): [slang][serializer] Ast producing bug
// https://github.com/MikePopoloski/slang/issues/1299
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
interface bus();
	logic w;
endinterface

module m1(bus intf);
	assign intf.w = 0;
endmodule

module top();
	bus intf1();
	bus intf2();

	m1 a(.intf(intf1));
	m1 b(.intf(intf2));
endmodule

