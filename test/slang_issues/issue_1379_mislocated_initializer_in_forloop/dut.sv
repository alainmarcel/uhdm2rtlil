// MikePopoloski/slang#1379 (closed): Mislocated initializer in ForLoop
// https://github.com/MikePopoloski/slang/issues/1379
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module controller #(
    parameter NUM_CHANNELS = 1
) (
    input wire clk
);
    reg [31:0] ar [NUM_CHANNELS-1:0];
    always @(clk) begin
        for (int i = 0 ; i < NUM_CHANNELS; i = i + 1) begin
            ar[i] <= 0;
        end
    end
endmodule

