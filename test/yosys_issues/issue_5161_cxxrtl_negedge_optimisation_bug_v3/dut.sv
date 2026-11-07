// YosysHQ/yosys#5161 (closed): CXXRTL - negedge optimisation bug
// https://github.com/YosysHQ/yosys/issues/5161
// Code block(s) from the issue (variant v3); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top (
    input wire clk,
    output reg [3:0] out
);
    reg derived;

    initial derived = 0;
    always_ff @(posedge clk)
        derived <= ~derived;

    initial out = 5;
    always_ff @(posedge derived)
        out <= 10;

endmodule

