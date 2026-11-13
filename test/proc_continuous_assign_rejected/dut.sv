// A procedural continuous assignment (`assign` / `deassign`, IEEE 1800
// 10.6.1) in an always block overrides the variable's flip-flop driver while
// it is active -- no netlist can express that, and read_slang, read_verilog
// and Verilator all reject it (povik/sv-elab#166).  read_uhdm used to
// SEGFAULT here (an `assign_stmt` cast to `assignment`); it must now stop
// with "procedural continuous assignment (`assign`) in an always block is
// not synthesizable".  Listed in failing_tests.txt: the error IS the
// expected outcome.  test/TaskOutputArgument keeps the supported case, an
// `assign` inside a TASK body.
module top(clk, q, d, clr, set);
  input clk, d, clr, set;
  output q;
  logic q;

  always @(clr or set)
    if (clr)
      assign q = 0;
    else if (set)
      assign q = 1;
    else
      deassign q;

  always @(posedge clk)
    q <= d;
endmodule
