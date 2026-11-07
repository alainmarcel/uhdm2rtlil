// YosysHQ/yosys#6408 (closed): read_verilog -sv: size cast inside an operator expression in a concat member uses the uncast width, silently dropping upper concat members
// https://github.com/YosysHQ/yosys/issues/6408
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
// repro.sv
module repro(input wire [3:0] a, input wire [1:0] w, output wire [4:0] y, output wire z);
  assign y = {3'b010, (2'(a) ^ w)};   // size cast inside an operator expression that is a concat member
  assign z = |2'(a);                   // reduction operator before a size cast
endmodule

