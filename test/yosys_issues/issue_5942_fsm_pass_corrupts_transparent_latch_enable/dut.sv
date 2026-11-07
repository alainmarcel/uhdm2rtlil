// YosysHQ/yosys#5942 (closed): fsm pass corrupts transparent latch enable logic, swapping hold and update conditions
// https://github.com/YosysHQ/yosys/issues/5942
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top(clkin_data, in_data, out_data);
  input [255:0] clkin_data;
  input [191:0] in_data;
  output [191:0] out_data;

  reg [8:0] state_b;
  wire next_bit = | in_data[177:173];

  always_latch
    if (!clkin_data[128]) state_b = 9'h000;
    else if (clkin_data[224]) state_b = { 3'b000, next_bit, 5'b00000 };

  assign out_data = {59'b0, ~state_b[5], 132'b0};
endmodule

