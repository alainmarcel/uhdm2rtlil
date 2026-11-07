// YosysHQ/yosys#5212 (closed): multiple drivers on a variable in a module change values of input ports when using `prep`
// https://github.com/YosysHQ/yosys/issues/5212
// Code block(s) from the issue (variant h0); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module simple_sub (
    input logic [7:0] a,
    input logic [7:0] b,
    output logic [7:0] a_out,
    output logic [7:0] b_out,
    output logic [7:0] diff
);
    wire [7:0] conflict_wire;
    assign a_out = a;
    assign b_out = b;
    assign conflict_wire = b;
    assign conflict_wire = a;
    assign diff = a - b;
    always_comb assert(b != a);
endmodule

module top;
    logic [7:0] a, b, a_out, b_out, diff;
    
    assign a = 8'hAA;
    assign b = 8'h55;

    simple_sub dut (
        .a(a),
        .b(b),
        .a_out(a_out),
        .b_out(b_out),
        .diff(diff)
    );

endmodule

