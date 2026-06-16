package pkg;
   typedef struct packed {
      logic 	  x;
   } a;
   typedef a[1:0] b;
endpackage

// Exercise typedef'd PACKED array-of-struct indexing (`c[i].x`) with every
// element driven so the design is fully controllable/observable (no dead X).
module top(input [1:0] din, output [1:0] o);
   pkg::b c;
   assign c[0].x = din[0];
   assign c[1].x = din[1];
   assign o = {c[1].x, c[0].x};
endmodule
