// YosysHQ/yosys#3288 (open): BTOR Support for $slice
// https://github.com/YosysHQ/yosys/issues/3288
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module test (clk, rst, add, cnt);
    input clk;
    input rst;
    input [3:0] add;
    output reg [3:0] cnt;
    
    initial cnt = 0;
    always @(posedge clk) begin
        cnt <= cnt + add;
        if (rst) cnt <= 0;
    end
    assert property (cnt != 4'b0100);
    assume property (add[2:1] == 2'b00);
endmodule

