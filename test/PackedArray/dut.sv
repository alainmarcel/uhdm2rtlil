package pkg;
  typedef struct packed {
    logic        x;
  } struct_a;

  typedef struct packed {
    struct_a [1:0] a;
  } struct_b;

endpackage

// Drive/observe every array element so the design is fully
// controllable/observable (no dead undriven-X bits).
module top(input [1:0] i, output [1:0] o);
   pkg::struct_b b;
   assign b.a[0].x = i[0];
   assign b.a[1].x = i[1];
   assign o = {b.a[1].x, b.a[0].x};
endmodule // top
