// MikePopoloski/slang#1388 (closed): [bug][slang-netlist] Bug with named port connection
// https://github.com/MikePopoloski/slang/issues/1388
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m(input w);
    t tt(.w(w));
endmodule


module t(wire w);
endmodule

