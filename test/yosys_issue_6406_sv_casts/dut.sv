// YosysHQ/yosys#6406 "Support SystemVerilog data type casts" -- the feature
// request that collapsed #6331 (a size cast of a constant operand folded at its
// self-determined width), #6332 (the result width of a size cast leaked the
// operand's width into the enclosing expression), #6401 (data type casts to
// signed types lost the target signedness) and #6408 (a size cast inside a
// concatenation).  The module is yosys's own tests/verilog/signed_casts.ys
// (PR #6439) with every checked value exposed as an output; the expected
// values in test_structural.ys are the reference values from Icarus Verilog
// that the upstream test asserts.  One upstream check is NOT here: a cast to a
// `union packed signed` -- UHDM's union_typespec carries no signedness, so
// Surelog cannot record it; test/yosys_issue_6401_union_signed_cast tracks it.
module dut (
  input  logic [3:0]  in,
  output logic [32:0] shift_unsized, shift_sized, shift_parameter, shift_subtract,
  output logic [9:0]  multiply_widened,
  output logic [7:0]  add_parameter_width, add_literal_width, add_cast_parameters,
                      subtract_mixed_widths, add_negative, negate_cast, complement_cast,
                      add_cast_signal,
  output logic [8:0]  add_widened,
  output logic [1:0]  concat_cast,
  output logic [63:0] byte_signed, typedef_signed, typedef_unsigned, struct_signed,
                      union_unsigned, shortint_widened
);
  localparam B = 1;
  localparam int unsigned W = 8;
  localparam int P = 255;

  typedef logic signed [7:0] signed_byte;
  typedef logic [7:0] unsigned_byte;
  typedef struct packed signed { logic [7:0] value; } signed_struct;
  typedef union packed unsigned { logic signed [7:0] value; } unsigned_union;

  wire [7:0] a = 8'hAC;
  wire [3:0] b = 4'h2;

  // 6331
  assign shift_unsized    = 33'(1 << 31);
  assign shift_sized      = 33'(1'b1 << 31);
  assign shift_parameter  = 33'(B << 31);
  assign shift_subtract   = 33'((1 << 31) - 1);
  assign multiply_widened = 10'(4'hF * 6'hA);
  // 6332
  assign add_parameter_width   = W'(5) + 8'hff;
  assign add_literal_width     = 8'(5) + 8'hff;
  assign add_cast_parameters   = W'(5) + W'(P);
  assign subtract_mixed_widths = 8'(3) - W'(5);
  assign add_negative          = 8'(-1) + 8'd1;
  assign negate_cast           = -W'(5);
  assign complement_cast       = ~W'(5);
  assign add_cast_signal       = W'(in) + 8'hff;
  assign add_widened           = W'(5) + 8'hff;
  // 6408
  assign concat_cast = {1'b1, (1'(b) ^ 1'b0)};
  // 6401
  assign byte_signed      = byte'(a);
  assign typedef_signed   = signed_byte'(a);
  assign typedef_unsigned = unsigned_byte'($signed(a));
  assign struct_signed    = signed_struct'(a);
  assign union_unsigned   = unsigned_union'(a);
  assign shortint_widened = shortint'(a);
endmodule
