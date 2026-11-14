// YosysHQ/yosys#5212 (closed): multiple drivers on a variable in a module change values of input ports when using `prep`
// https://github.com/YosysHQ/yosys/issues/5212
// Code block(s) from the issue (variant h1); harvested by test/yosys_issues/harvest.py

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
endmodule

module top (__o_a, __o_a_out, __o_b, __o_b_out, __o_diff);
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


  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic [7:0] __o_a;
  assign __o_a = a;
  output logic [7:0] __o_a_out;
  assign __o_a_out = a_out;
  output logic [7:0] __o_b;
  assign __o_b = b;
  output logic [7:0] __o_b_out;
  assign __o_b_out = b_out;
  output logic [7:0] __o_diff;
  assign __o_diff = diff;
endmodule

