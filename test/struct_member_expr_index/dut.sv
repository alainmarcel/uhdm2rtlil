// A struct member indexed by a compile-time EXPRESSION rather than a literal.
//
// `value.mantissa[MAN_BITS-1]` reaches the importer as the TEXT
// `mantissa[23 - 1]`; only the leading integer was parsed, so bit 23 was
// selected instead of bit 22.
package p;
  localparam int unsigned EXP_BITS = 8;
  localparam int unsigned MAN_BITS = 23;
  typedef struct packed {
    logic                sign;
    logic [EXP_BITS-1:0] exponent;
    logic [MAN_BITS-1:0] mantissa;
  } fp_t;
  typedef struct packed {
    logic [1:0][7:0] pair;      // an ARRAY member: [i] means an ELEMENT
    logic [3:0]      tag;
  } arr_t;
endpackage

module dut (
    input  logic [31:0] word_i,
    input  logic [19:0] arr_i,
    output logic        man_msb_o,
    output logic        man_msb_lit_o,
    output logic        man_lsb_o,
    output logic        exp_msb_o,
    output logic [7:0]  elem_o,
    output logic [7:0]  elem_expr_o
);
  p::fp_t  value;
  p::arr_t av;
  assign value = word_i;
  assign av    = arr_i;

  // The failing shape: index is an expression.
  assign man_msb_o     = value.mantissa[p::MAN_BITS-1];
  // Same bit, written as a literal — these two must agree.
  assign man_msb_lit_o = value.mantissa[22];
  assign man_lsb_o     = value.mantissa[p::MAN_BITS-23];
  assign exp_msb_o     = value.exponent[p::EXP_BITS-1];

  // Control: on an ARRAY member the index selects a whole ELEMENT, not a
  // bit — folding the index must not change that.
  assign elem_o        = av.pair[1];
  assign elem_expr_o   = av.pair[p::MAN_BITS-22];
endmodule
