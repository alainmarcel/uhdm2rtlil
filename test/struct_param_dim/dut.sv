// Reproduction of a Surelog/Synlig segfault: array dimensions defined
// using a field from a struct-typed parameter.  Made synthesizable here
// so input is controllable and output observable.

typedef struct packed { logic [31:0] t; } test_struct_t;

module test_module #(
    parameter test_struct_t pt = 32'h4
) (
    input  logic [3:0] in,
    input  logic [1:0] idx,
    output logic       out
);
  // Original segfault trigger: unpacked array dimension is the struct
  // field `pt.t`.
  logic mem[pt.t];

  assign mem[0] = in[0];
  assign mem[1] = in[1];
  assign mem[2] = in[2];
  assign mem[3] = in[3];

  assign out = mem[idx];
endmodule

module top (
    input  logic [3:0] a,
    input  logic [1:0] sel,
    output logic       y
);
  test_module inst (.in(a), .idx(sel), .out(y));
endmodule
