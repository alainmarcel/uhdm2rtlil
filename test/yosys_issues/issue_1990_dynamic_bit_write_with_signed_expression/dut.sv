// YosysHQ/yosys#1990 (closed): Dynamic bit write with signed expression fails
// https://github.com/YosysHQ/yosys/issues/1990
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- c0.sv
module top (
        input [31:0] din,
        input signed [4:0] n,
        output reg [31:0] dout
);
        always @(*) begin
                // avoid logic loop issue
                dout = 0;

                // this version fails
                // dout[n^1] = din[n];

                // this version works
                dout[n^1 +: 1] = din[n];
        end
endmodule

