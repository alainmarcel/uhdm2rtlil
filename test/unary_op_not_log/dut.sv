/*
:name: unary_op_not_log
:description: ! operator test
:tags: 11.3
*/
// `b` is intentionally narrow so random co-sim stimulus hits b==0 often
// enough that `!b` toggles (a wide `int` would be non-zero ~always → vacuous).
module top(input [3:0] b, output a);
   assign a = !b;
endmodule