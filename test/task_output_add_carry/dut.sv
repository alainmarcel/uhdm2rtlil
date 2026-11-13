// sv-elab regress.sv r18: a task whose OUTPUT formal is wider than the
// operands of the sum it is assigned (`o = x + y`, 8-bit x / y, 9-bit o).
// The sum is context-determined, so the carry lands in o[8].  read_uhdm
// imported the task body's RHS without the LHS width and dropped it:
// 255 + 1 read 0.  The `return` of the original r18 is kept.
module top(input logic [7:0] a, input logic [7:0] b, output logic [8:0] out);
  task sum(logic [7:0] x, logic [7:0] y, output logic [8:0] o);
    o = x + y;
    return;
  endtask
  always_comb sum(a, b, out);
endmodule
