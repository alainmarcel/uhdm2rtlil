// YosysHQ/yosys#647: an internal wire of a child instance read through dot
// notation (`myfoo.test`) was not accessible in read_verilog.  The read must
// see the child's internal value: x follows ~i.
module foo (input i);
  wire test = ~i;
endmodule
module dut (input i, output x);
  foo myfoo (.i(i));
  assign x = myfoo.test;
endmodule
