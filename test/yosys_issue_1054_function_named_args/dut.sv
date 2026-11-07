// YosysHQ/yosys#1054: a function call with NAMED argument binding
// (`test(.a(a), .b(b))`) was a syntax error in read_verilog.  Both call forms
// must give the same 1-bit sum (a ^ b after truncation).
module dut (input a, input b, output c, output d);
  function automatic f(input x, input y);
    f = x + y;
  endfunction
  assign c = f(.x(a), .y(b));
  assign d = f(.y(b), .x(a));
endmodule
