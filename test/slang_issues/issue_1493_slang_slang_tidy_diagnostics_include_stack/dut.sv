// MikePopoloski/slang#1493 (closed): [slang][slang-tidy] Diagnostics include stack printed only once
// https://github.com/MikePopoloski/slang/issues/1493
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module lib_top(
    input logic a,
    inout logic b,
    output logic c
);

    reg bb;
    always_comb begin
        if (a)
            bb = c;
    end

endmodule

