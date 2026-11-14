// MikePopoloski/slang#983 (closed): -Wunused-but-set-net behavior for a wire connecting two inout ports together
// https://github.com/MikePopoloski/slang/issues/983
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m(
    inout wire a
);
    wire local_a;
    pullup(local_a);
    tranif1(a, local_a, 1'b1);
endmodule

module top;
    wire a;

    m m1(
       // .a (a)
       .*
    );

    m m2(
       // .a (a)
       .*
    );

endmodule

