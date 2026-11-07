// YosysHQ/yosys#6331 (closed): `read_verilog -sv`: a size cast of a constant operand folds the operand at its self-determined width, then extends it
// https://github.com/YosysHQ/yosys/issues/6331
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module t(input logic b, output logic [32:0] y0, y1, y2, y3, output logic [9:0] m);
  assign y0 = 33'(1 << 31);        // yosys: 33'h1_8000_0000   expected 33'h0_8000_0000  (int folded at 32 bits -> -2**31, sign-extended)
  assign y1 = 33'(1'b1 << 31);     // yosys: 33'h0             expected 33'h0_8000_0000  (folded at 1 bit)
  assign y2 = 33'(b << 31);        // yosys: 33'h0_8000_0000 for b=1 (correct: non-constant operand)
  assign y3 = 33'(1) << 31;        // yosys: 33'h0_8000_0000 (correct: cast before the shift)
  assign m  = 10'(4'hF * 6'hA);    // yosys: 22                expected 150 (product folded at 6 bits)
endmodule

