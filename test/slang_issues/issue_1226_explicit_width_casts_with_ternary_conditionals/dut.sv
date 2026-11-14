// MikePopoloski/slang#1226 (closed): Explicit width-casts with ternary-conditionals can trigger -Wwidth-expand
// https://github.com/MikePopoloski/slang/issues/1226
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top;

    localparam int unsigned SIZE = 16;

    logic a;
    logic [7:0] b, c;
    logic [SIZE-1:0] d, e, f;

    always_comb begin
        d = SIZE'( a ? b : c);
        e = SIZE'(b);
        f = a ? SIZE'(b) : SIZE'(c);
    end

endmodule

