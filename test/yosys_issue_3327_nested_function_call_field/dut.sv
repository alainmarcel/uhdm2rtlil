// YosysHQ/yosys#3327: read_verilog failed to parse a two-level-deep function
// call in an always_comb when the inner function reads a module variable
// (`a = f1(); f1 = f2(); f2 = b;`).  The value must flow: a == b.
module dut (input int b, output int a);
  always_comb begin
    a = f1();
  end
  function int f1();
    f1 = f2();
  endfunction
  function int f2();
    f2 = b;
  endfunction
endmodule
