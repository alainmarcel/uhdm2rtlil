// YosysHQ/yosys#6108 (closed): write_smt2 silently drops assertions ($check cells not handled)
// https://github.com/YosysHQ/yosys/issues/6108
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module counter(input clk, input rst, output reg [3:0] count);
    always @(posedge clk) begin
        if (rst) count <= 4'd0;
        else count <= count + 4'd1;
    end
    assert property (count != 4'd15);
endmodule

