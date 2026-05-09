// Reproduction of synlig/Yosys hierarchy-pass error:
//   "Output port b.a_inst.a1 (a) is connected to constants: { ... 1'0 }"
//
// Inner module `a` declares 3-bit output `a1` but does not drive it.
// Module `b` instantiates `a` with `.a1(b2)` where `b2` is an implicit
// 1-bit net (declared via the `assign b2 = 'b0;` line below).  The
// width mismatch causes hierarchy to pad the cell port with constant
// 1'b0 bits, and a later hierarchy pass treats that as "output
// connected to constants" and errors.
//
// Synthesizable wrapper added so `b2` is observable through `b1`.

module a (output logic [4:2] a1, output logic a2);
endmodule: a

module b (output logic b1);
  a a_inst(.a1(b2), .a2(b1));
  assign b2 = 'b0;
endmodule: b

module top (output logic out);
  b inst (.b1(out));
endmodule
