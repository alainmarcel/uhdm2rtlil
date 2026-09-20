// `'{default: <struct localparam>}` on an UNPACKED ARRAY of a packed struct
// filled every element bit with 1 instead of replicating the struct's value.
//
// The assignment-pattern handler has two paths.  When the TARGET is a struct it
// walks the members; otherwise it falls to a packed-vector path that replicates
// the fill BITWISE — correct for `'{default: 0}` / `'{default: 1}`, where the
// elements are single bits.  An unpacked array of a packed struct is neither:
// `members` is null (the target is an array, not a struct), so it took the
// bitwise path, the element width stayed 1, and a constant non-zero fill was
// replicated as its truthiness — all ones.
//
// An all-zero default hides the bug completely (zeros replicate to zeros),
// which is why it survived so long: only a default with a NON-ZERO field shows
// it.  OTBN's otbn_mac_bignum_fsm does exactly this with
// `predec_vec = '{default: PredecDynDefault}`, whose `mul_op_a_tmp_sel` field
// defaults to 1'b1.
//
// The discriminator is the pattern's own typespec: a struct/union/packed-array
// default is element-typed by construction, while a bare integer literal is not
// and must keep the bitwise semantics.
package p;
  typedef struct packed {
    logic [1:0] a;
    logic       tmp;      // non-zero in the default — the bit that was lost
    logic [1:0] b;
  } t;
  localparam t D = '{a: 2'b10, tmp: 1'b1, b: 2'b01};   // 5'b10101
  localparam t Z = '{a: 2'b00, tmp: 1'b0, b: 2'b00};   // all-zero control
endpackage

module array_default_struct_pattern (
  input  logic [1:0]  v,
  input  logic [1:0]  idx,
  output logic [9:0]  o_plain,    // '{default: D} with no further writes
  output logic [9:0]  o_written,  // '{default: D} then per-element field writes
  output logic [9:0]  o_zero,     // all-zero default — the shape that always worked
  output logic [4:0]  o_dyn,      // dynamic element read of the defaulted array
  output logic [3:0]  o_bitwise   // '{default: 1} on a plain vector — must stay bitwise
);
  p::t vec  [2];
  p::t vecw [2];
  p::t vecz [2];
  logic [3:0] bits;

  always_comb vec = '{default: p::D};

  always_comb begin
    vecw = '{default: p::D};
    for (int unsigned c = 0; c < 2; c++) vecw[c].a = v;
  end

  always_comb vecz = '{default: p::Z};

  always_comb bits = '{default: 1'b1};   // plain vector: every BIT set

  assign o_plain   = {vec[1],  vec[0]};
  assign o_written = {vecw[1], vecw[0]};
  assign o_zero    = {vecz[1], vecz[0]};
  assign o_dyn     = vec[idx[0]];
  assign o_bitwise = bits;
endmodule
