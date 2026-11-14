// MikePopoloski/slang#1957 (closed): False-positive for Winferred-latch and unique-case statements
// https://github.com/MikePopoloski/slang/issues/1957
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m(
    input logic a,
    input logic b,
    input logic c,
    input logic d,
    input logic e
);
    logic [4:0] y;

    always_comb begin
        logic [4:0] sel;
        sel = { a, b, c, d, e };
        unique casez (1'b1)
            sel[4]: y = 16;
            sel[3]: y = 8;
            sel[2]: y = 4;
            sel[1]: y = 2;
            sel[0]: y = 1;
        endcase
    end

endmodule

