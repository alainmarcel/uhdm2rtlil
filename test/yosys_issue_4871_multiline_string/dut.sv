// YosysHQ/yosys#4871: Support for multi-line string for system verilog
// https://github.com/YosysHQ/yosys/issues/4871
// A string literal continued over a line break with a backslash (LRM 5.9), in an attribute.

module dut(output logic [7:0] y);
  (* desc = "a very \
long attribute" *) logic [7:0] q;
  assign q = 8'd5;
  assign y = q;
endmodule
