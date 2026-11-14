// MikePopoloski/slang#1702 (closed): Unlabeled generate-if and -Wshadow
// https://github.com/MikePopoloski/slang/issues/1702
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top;
    localparam bit A = 1'b1;
    localparam bit B = 1'b1;

    if (A) begin
        if (B) begin
            always_comb begin
            end
        end
    end

endmodule

