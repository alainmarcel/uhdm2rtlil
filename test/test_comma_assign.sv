module test_comma_assign(input [31:0] a, b, output [7:0] x, y, z, w);
  // Test with separate assignments
  assign x = a - b;
  assign y = a * b;
  assign z = a >> b;
  assign w = a << b;
endmodule
