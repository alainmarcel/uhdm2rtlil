// YosysHQ/yosys#3689 (open): Error for partly out-of-bounds part selections
// https://github.com/YosysHQ/yosys/issues/3689
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): top's x comes from a new input xi and y is observable on yo (x was the constant 1 and top had no ports); the partly out-of-bounds select is unchanged

// ---- c0.sv
module dut(x, y);
    input [2:0] x;
    output [3:0] y;
    localparam [5:15] p = 51681708;
    assign y = p[15 + x -: 5];
endmodule

module top(input logic [2:0] xi, output logic [3:0] yo);
    logic [3:0] y;
    logic [2:0] x;
    assign x = xi;
    assign yo = y;
    dut dut(x, y);
    always_comb assert(y[3] === 1'b1);
endmodule

