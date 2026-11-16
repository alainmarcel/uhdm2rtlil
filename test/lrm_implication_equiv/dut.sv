// IEEE 1800-2023 11.4.7: logical implication (->) and equivalence (<->).
// Both operate on the truth value of each operand, so a multi-bit operand is
// true when any bit is 1.
module dut(input  logic a, b, input logic [3:0] v, w,
           output logic imp, eqv, vimp, veqv);
  assign imp  = a -> b;
  assign eqv  = a <-> b;
  assign vimp = v -> w;
  assign veqv = (v & w) <-> (v | w);
endmodule
