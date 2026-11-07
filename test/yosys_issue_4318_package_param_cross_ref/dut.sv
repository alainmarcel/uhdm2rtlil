// YosysHQ/yosys#4318: a package localparam initialised from ANOTHER package's
// parameter (`localparam int MY_CONST = my_const::MY_CONST;`) was reported as
// an implicitly declared identifier by read_verilog.  Both package functions
// must return 5.
package my_const;
  localparam int MY_CONST = 5;
endpackage
package test1;
  function int test1();
    test1 = my_const::MY_CONST;
  endfunction
endpackage
package test2;
  localparam int MY_CONST = my_const::MY_CONST;
  function int test2();
    test2 = MY_CONST;
  endfunction
endpackage
module dut (output int a, output int b, output int c);
  assign a = test1::test1();
  assign b = test2::test2();
  assign c = test2::MY_CONST + 1;
endmodule
