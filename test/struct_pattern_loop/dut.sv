// Reproduction of an "ABC combinational loop" error reported on:
//   module a(output bit [0:0][0:0] b [0:0]);
//     assign b = '{'b0};
//   endmodule
//
// Wrapped in a synthesizable top so the output is observable.

module a (output bit [0:0][0:0] b [0:0]);
  assign b = '{'b0};
endmodule

module top (output bit out);
  bit [0:0][0:0] b_internal [0:0];
  a inst (.b(b_internal));
  assign out = b_internal[0][0][0];
endmodule
