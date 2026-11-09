// YosysHQ/yosys#3549 (open): CXXRTL edge detector not working for non-input clocks
// https://github.com/YosysHQ/yosys/issues/3549
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): the divided-clock counter is observable on a new output cnt (the snippet had no output)

// ---- b0.sv
module top (input logic clk, output logic [7:0] cnt);
    assign cnt = counter;
    logic[7:0] counter;
    logic clkdiv;
    always_ff @(posedge clk) clkdiv <= ~clkdiv;
    always_ff @(posedge clkdiv) counter <= counter + 1;
endmodule

