// MikePopoloski/slang#1356 (open): Generic `interconnect` (`UntypedType`) bit width is always 0 with `Type::getBitstreamWidth()`
// https://github.com/MikePopoloski/slang/issues/1356
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- c0.sv
module netlist;
  wire w;
  dut1 child1(w);
  dut2 child2(w);
  initial #10 $display(w);
endmodule
module dut1(wand w);
  assign w = 1;
endmodule
module dut2(wor w);
  assign w = 0;
endmodule

