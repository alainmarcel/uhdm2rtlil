// MikePopoloski/slang#1632 (closed): `--allow-use-before-declare` not working when localparam referenced from port declaration
// https://github.com/MikePopoloski/slang/issues/1632
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module DFFRAM_4K
(
    CLK,
    WE,
    EN,
    Di,
    Do,
    A
);

    input           CLK;
    input   [3:0]   WE;
    input           EN;
    input   [31:0]  Di;
    output  [31:0]  Do;
    input   [7+$clog2(COLS):0]   A;

    //WBD
    localparam COLS=4;


endmodule

