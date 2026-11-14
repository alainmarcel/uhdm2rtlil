// MikePopoloski/slang#1908 (closed): RegisterHasNoReset not working
// https://github.com/MikePopoloski/slang/issues/1908
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top(input clk_i, rst_n_i);
    logic a;
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if(~rst_n_i) begin
        end else begin
            a <= 1;
        end
    end
endmodule // top

