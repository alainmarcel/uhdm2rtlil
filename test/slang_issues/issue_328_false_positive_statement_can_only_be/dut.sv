// MikePopoloski/slang#328 (closed): False positive 'statement can only be used inside a loop'
// https://github.com/MikePopoloski/slang/issues/328
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module foo;
    always_comb
        for(int p = 0; p < 4; p++) begin
            automatic int bar;
            break;
        end
endmodule

