// YosysHQ/yosys#2762 (closed): Double-equal (==) operator not working as intended
// https://github.com/YosysHQ/yosys/issues/2762
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
// broken.sv
`default_nettype none
// Empty top module

module top1 (
  input logic hz100, reset,
  output logic [7:0] right,
  output logic red
);

  // Your code goes here...
  always_ff @(posedge hz100, posedge reset)
  if (reset)
    right <= 0;
  else
    right <= clk ? 0 : right + 1;
  
  logic clk;
  assign clk = right == 8'd99;    // Different from fixed.sv
  always @(posedge clk, posedge reset)
  if (reset)
    red <= 0;
  else
    red <= ~red;

endmodule

// ---- b1.sv
// fixed.sv
`default_nettype none
// Empty top module

module top2 (
  input logic hz100, reset,
  output logic [7:0] right,
  output logic red
);

  // Your code goes here...
  always_ff @(posedge hz100, posedge reset)
  if (reset)
    right <= 0;
  else
    right <= clk ? 0 : right + 1;
  
  logic clk;
  assign clk = &(right ~^ 8'd99);   // Different from broken.sv
  always @(posedge clk, posedge reset)
  if (reset)
    red <= 0;
  else
    red <= ~red;

endmodule

// ---- b2.sv
`timescale 1ns/1ns

module main;
    reg hz100;
    wire reset;
    reg [20:0] pb;
    wire [7:0] right1, right2;
    wire red1, red2;

    top1 ice401 (
        .hz100(hz100),
        .reset(reset),
        .right(right1),
        .red(red1)
    );
        
    top2 ice402 (
        .hz100(hz100),
        .reset(reset),
        .right(right2),
        .red(red2)
    );

    reset_on_start ros (
        .reset(reset), 
        .clk(hz100), 
        .manual(pb[3]&&pb[0]&&pb[16])
    );

    integer i = 0;

    initial begin
      $dumpfile("trace.vcd");
      $dumpvars(0, main);
      pb = 0;
      for (i = 0; i < 4; i++) begin
        hz100 = 1; #1; hz100 = 0; #1;   // clock until reset goes low
      end
      for (i = 0; i < 198; i++) begin
        hz100 = 1; #1; hz100 = 0; #1;   // clock 
        $display("i: %3d ---> right1: %3d, right2: %3d, red1: %1d, red2: %1d", i, right1, right2, red1, red2);
      end
    end
endmodule

module reset_on_start(
    output reset,
    input clk,
    input manual
);
  logic [2:0] startup = 0;
  assign reset = startup[2] | manual;    // MSB drives the reset signal
  always @ (posedge clk, posedge manual)
    if (manual == 1)
      startup <= 0;             // start with reset low to get a rising edge
    else if (startup == 0)
      startup <= 4;             // hold reset high for 4 cycles
    else if (startup == 4)
      startup <= 5;
    else if (startup == 5)
      startup <= 6;
    else if (startup == 6)
      startup <= 7;
    else if (startup == 7)
      startup <= 1;             // Final state is 1.
endmodule

