// MikePopoloski/slang#2108 (closed): Items of a `case` that a constant case expression does not select are still checked, unlike `if` and `?:`
// https://github.com/MikePopoloski/slang/issues/2108
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m #(parameter int aw = 4) (input logic [aw:1] q, output logic a, b, c);
    always_comb begin
        if (aw == 5) a = q[5] ^ q[3];
        else a = q[4] ^ q[3];

        case (aw)
            5: c = q[5] ^ q[3];
            default: c = q[4] ^ q[3];
        endcase
    end

    assign b = aw == 5 ? q[5] ^ q[3] : q[4] ^ q[3];
endmodule

// ---- b1.sv
module lfsr #(parameter int aw = 3) (input logic clk, output logic [aw:1] q);
    logic fb;
    always_comb
        case (aw)
            2: fb = q[2] ^ q[1];
            3: fb = q[3] ^ q[2];
            4: fb = q[4] ^ q[3];
            5: fb = q[5] ^ q[3];
            default: fb = q[aw] ^ q[1];
        endcase
    always_ff @(posedge clk) q <= {q[aw-1:1], fb};
endmodule

