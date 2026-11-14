// MikePopoloski/slang#1285 (closed): Spurious mutliple assignments error with interfaces and instance caching
// https://github.com/MikePopoloski/slang/issues/1285
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

