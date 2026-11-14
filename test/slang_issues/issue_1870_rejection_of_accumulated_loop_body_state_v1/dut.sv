// MikePopoloski/slang#1870 (closed): Rejection of accumulated loop body state
// https://github.com/MikePopoloski/slang/issues/1870
// Code block(s) from the issue (variant v1); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m(input in);
    reg c;
    always_comb begin
        automatic int j = 4;
        for (int i = 0; i < (i == 0 ? 4 : j); i++) begin
            c = in;
        end
    end
endmodule

