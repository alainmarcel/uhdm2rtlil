// YosysHQ/yosys#5917 (closed): Follow up to #5906 Nexus DSP techmap is missing MULT* register absorption
// https://github.com/YosysHQ/yosys/issues/5917
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module nx_mul18_pipe(
    input  logic clk,
    input  logic [17:0] a,
    input  logic [17:0] b,
    output logic [35:0] y
);
    logic [17:0] a_r;
    logic [17:0] b_r;

    always_ff @(posedge clk) begin
        a_r <= a;
        b_r <= b;
        y <= a_r * b_r;
    end
endmodule

