// YosysHQ/yosys#538: Support system verilog labeled statements
// https://github.com/YosysHQ/yosys/issues/538
// Statement labels (LRM 9.3.5) on a begin/end block and on an if inside always_comb.  The issue's own module-level 'bbb: begin end' is not legal SystemVerilog (a bare begin/end is no module item); the procedural form is.

module dut(input logic a, b, output logic y, z);
  always_comb begin
    lbl1: begin y = a & b; end
    lbl2: if (a) z = b; else z = ~b;
  end
endmodule
