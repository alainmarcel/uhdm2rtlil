// MikePopoloski/slang#2057 (closed): Instance passed as an argument to the same sequence or property is treated as recursive
// https://github.com/MikePopoloski/slang/issues/2057
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top(input logic clk, a, b, c);
    sequence s(x, y);
        x ##1 y;
    endsequence

    property p1(x, property q);
        x |=> q;
    endproperty

    property p2(x, property q);
        x |-> q;
    endproperty

    c1: cover property (@(posedge clk) s(a, s(b, c).triggered));
    a1: assert property (@(posedge clk) p2(a, p2(b, c)));
    a2: assert property (@(posedge clk) not p1(a, p1(b, c)));
endmodule

