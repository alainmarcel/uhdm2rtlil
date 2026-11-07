// YosysHQ/yosys#1752 (closed): Parameter with data type of 'logic' gives syntax errors.
// https://github.com/YosysHQ/yosys/issues/1752
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module example
  #(
    parameter integer               COUNTBITS = 8,
    parameter logic [COUNTBITS-1:0] MAXCOUNT  = 8'b1000000
  ) (
  input  wire        CLK, 
  output wire [15:0] LD
  );

  wire                clock;
  reg [15:0]          leds;
  reg [COUNTBITS-1:0] counter;

  assign LD    = leds;
  assign clock = CLK;

  always @(posedge clock) begin
    counter <= counter + 1;
    if (counter[COUNTBITS-1] == MAXCOUNT)
      leds <= 16'h8000 >> counter[COUNTBITS-2:COUNTBITS-5];
    else
      leds <= 16'h0001 << counter[COUNTBITS-2:COUNTBITS-5];
  end
endmodule

