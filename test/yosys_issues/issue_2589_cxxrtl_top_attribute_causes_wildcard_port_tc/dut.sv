// YosysHQ/yosys#2589 (closed): CXXRTL: (* top *) attribute causes wildcard port connections (.*) to break
// https://github.com/YosysHQ/yosys/issues/2589
// Code block(s) from the issue (variant tc); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
(* top *)
module top(
        input  logic       clk,
        output logic [3:0] seq
    );

    test t(.*);
endmodule

module test(
        input  logic       clk,
        output logic [3:0] seq
    );

    always_ff @(posedge clk) seq++;
endmodule

