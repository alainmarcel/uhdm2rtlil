// MikePopoloski/slang#610 (closed): Width-mismatches on port-connections have no warning
// https://github.com/MikePopoloski/slang/issues/610
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m(
    input logic       clk,
    input logic [7:0] data1,
    input logic [7:0] data2
);
endmodule

module top;
    logic clk;
    logic [2:0] data2;

    m m(
        .clk   (clk),
        .data1 (data),
        .data2 (data2)
    );
endmodule

