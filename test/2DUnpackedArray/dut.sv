// Drive/observe every element of the 2-D unpacked array so the design is
// fully controllable/observable (no dead undriven-X bits).
module top(input [5:0] i, output [5:0] o);
   logic a [1:0][2:0];
   assign a[0][0] = i[0];
   assign a[0][1] = i[1];
   assign a[0][2] = i[2];
   assign a[1][0] = i[3];
   assign a[1][1] = i[4];
   assign a[1][2] = i[5];
   assign o = {a[1][2], a[1][1], a[1][0], a[0][2], a[0][1], a[0][0]};
endmodule
