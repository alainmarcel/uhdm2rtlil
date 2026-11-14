// MikePopoloski/slang#1432 (closed): [slang][ast] Continuous assignment instead of initializer
// https://github.com/MikePopoloski/slang/issues/1432
// Code block(s) from the issue (variant v2); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m();
wire w;
assign w = 1'b0;
endmodule

