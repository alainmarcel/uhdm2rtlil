// MikePopoloski/slang#1174 (closed): bitwise-op-parentheses and |= asignments
// https://github.com/MikePopoloski/slang/issues/1174
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top;
    logic [15:0] a;
    logic [15:0] b;
    logic c;

    always_comb begin
        for (int i = 0; i < 16; i++) begin
            c |= a[i] & b[i];
        end
    end

endmodule

