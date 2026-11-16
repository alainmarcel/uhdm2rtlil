// IEEE 1800-2023 6.24.1: const'(expr) casts to a constant of the same type;
// the value is unchanged.
module dut(input logic [7:0] a, b, output logic [7:0] y, output logic [8:0] s);
  assign y = const'(a) ^ b;
  assign s = const'(a) + const'(9'(b));
endmodule
