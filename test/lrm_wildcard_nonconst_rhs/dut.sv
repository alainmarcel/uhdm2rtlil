// IEEE 1800-2023 11.4.6: wildcard equality whose right operand is NOT a
// constant.  X/Z bits of the right operand are don't-cares wherever they come
// from; here they come from the constant half of a concatenation, so bits
// [3:0] of `w` and bits [7:4] of `v` are ignored.  read_slang and Verilator
// both refuse a non-constant right operand, so test_structural.ys proves the
// values directly.
module dut(input logic [7:0] a, b, c, output logic w, v);
  assign w = a ==? {b[7:4], 4'bxxxx};
  assign v = a !=? {4'bzz11, c[3:0]};
endmodule
