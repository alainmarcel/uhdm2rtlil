// YosysHQ/yosys#6002 (open): Assertion in hierarchy when elaborating parameterized generate instances due to non-unique name
// https://github.com/YosysHQ/yosys/issues/6002
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- c0.sv
module child #(parameter integer ID = 0) (
  input wire a, output wire [31:0] y
);
  assign y = {32{a}} ^ ID;
endmodule

module top #(parameter integer NUM = 4) (
  input wire a, output reg [31:0] y
);
  wire [31:0] z [NUM];
  for (genvar g = 0; g < NUM; g = g + 1) begin : sm
    child #(.ID(g)) u (.a(a), .y(z[g]));
  end
  integer i;
  always_comb begin
    y = 0;
    for (i = 0; i < NUM; i = i + 1)
      y = y | z[i];
  end
endmodule

