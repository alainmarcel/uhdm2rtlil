// Test for packed-array typedef on top of an enum: `typedef u [0:1] crash;`
// The name `crash` was reported to segfault Surelog/synlig (the alternate
// name `yeah` was said to work).  Surelog no longer crashes on either.
//
// Uses the implicit enum base type (defaults to `int` = 32 bits per LRM)
// to also exercise the packed_array_typespec width computation:
// `u [0:1]` should be 64 bits (2 elements x 32-bit `int`).

module m (
    input  logic [63:0] in,
    input  logic        sel,
    output logic [31:0] out_a,
    output logic [31:0] out_b
);
  typedef enum { FALSE, TRUE } u;
  typedef u [0:1] yeah;      // alternate name — was reported to work
  typedef u [0:1] crash;     // the segfault-trigger name

  yeah  a;
  crash b;
  assign a = in;
  assign b = in;
  assign out_a = sel ? a[0] : a[1];
  assign out_b = sel ? b[0] : b[1];
endmodule
