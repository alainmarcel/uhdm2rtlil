// YosysHQ/yosys#1022 (closed): Error parsing systemverilog integer literal constants 
// https://github.com/YosysHQ/yosys/issues/1022
// Code block(s) from the issue (variant v4); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module test(
  output logic [31:0] b
);

  assign b = 32'b1;

endmodule

