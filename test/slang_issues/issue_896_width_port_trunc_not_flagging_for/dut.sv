// MikePopoloski/slang#896 (closed): width-port-trunc not flagging for 32-bit expression in port list
// https://github.com/MikePopoloski/slang/issues/896
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module M(
    input bit [3:0] a
);
endmodule

module top;
    localparam USED_A = 2;
    bit [3:0] a1;
    bit [8:0] a2;

    M m1(
        .a(a1 & (2**USED_A - 1))
    );

    M m2(
        .a(a2 & (2**USED_A - 1))
    );
endmodule

