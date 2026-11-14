// MikePopoloski/slang#944 (closed): Pattern variables are not visible from initializers in child scope
// https://github.com/MikePopoloski/slang/issues/944
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m;
    int i;
    always_comb begin
        if (i matches .a) begin
            automatic int pc = a; // 5
        end
    end
endmodule

