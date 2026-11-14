// MikePopoloski/slang#1895 (closed): Output port variable initializer is not treated as a driver
// https://github.com/MikePopoloski/slang/issues/1895
// Code block(s) from the issue (variant v1); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top(input clk, output reg [3:0] out = 1);
always @(posedge clk) begin
    out <= 2;
end
endmodule

