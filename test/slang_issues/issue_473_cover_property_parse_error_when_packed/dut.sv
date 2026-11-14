// MikePopoloski/slang#473 (closed): cover property parse error when packed array is used
// https://github.com/MikePopoloski/slang/issues/473
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top(
    input logic clk
);
    localparam I_MAX = 4;
    localparam J_MAX = 2;
    logic a, b, c;
    logic [J_MAX-1:0][I_MAX-1:0] sig_a, sig_b, sig_c;

    COVER_PASS: cover property ( @(posedge clk)
        a ##[0:$]
        b ##1
        c [*0:$] ##0
        ~c
    ) $info("%t %m HIT", $time);

    COVER_FAIL: cover property ( @(posedge clk)
        sig_a[0][0] ##[0:$]
        sig_b[0][0] ##1
        sig_c[0][0] [*0:$] ##0
        ~sig_c[0][0]
    ) $info("%t %m HIT", $time);

endmodule

