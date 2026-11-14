// MikePopoloski/slang#1252 (closed): False positives for -Winferred-latch when case-statements have default-statements
// https://github.com/MikePopoloski/slang/issues/1252
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top;
    typedef enum logic [2:0] {
        A, B, C, D,
        E, F, G, H
    } e_t;

    e_t e;
    logic x;

    always_comb begin
        case (e)
            A, B, C, D: x = 1'b1;
            default: x = 1'b0;
        endcase
    end
endmodule

