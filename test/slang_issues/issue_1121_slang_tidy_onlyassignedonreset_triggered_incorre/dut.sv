// MikePopoloski/slang#1121 (closed): [slang-tidy] OnlyAssignedOnReset triggered incorrectly with structs and for loops
// https://github.com/MikePopoloski/slang/issues/1121
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test;
    struct {
        logic x;
        logic z;
    } k [1:0];
    logic clk_i;
    logic rst_ni;
    logic a, b, c, d;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            k <= '{default: 0};
        end else begin
            for (int i = 0; i < 2; i++) begin
                if (d) begin
                    k[i].x <= 1'b1;
                    k[i].z <= 1'b1;
                end
            end
        end
    end
endmodule

