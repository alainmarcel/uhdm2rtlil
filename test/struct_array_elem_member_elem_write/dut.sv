// A trailing index on a struct member that is ITSELF a PACKED ARRAY, reached
// through an element of a packed array of structs: `bn.ops[k].b[j]`.
//
// `b` is `logic [3:0][7:0]`, so `b[j]` is an 8-bit ELEMENT at j*8 -- not bit j.
// The reader treated the trailing index as a BIT select and wrote one bit per
// element at consecutive low offsets, which is invisible on a one-bit element
// and silently wrong on every wider one (snitch spatz_ipu's SIMD distributor
// drove bits [144],[145],[146],[147] of its 496-bit lane bundle where the four
// bytes live at [151:144],[159:152],[167:160],[175:168], so three of four lanes
// saw zero operands).
//
// Both documented packed-multidim typespec shapes are covered: `b` is ONE
// logic_typespec with TWO ranges and no Elem_typespec, `h` is the same shape at
// 16 bits, and `w` is a plain vector member whose index must STAY a bit select.
module top (
    input  logic [31:0] d,
    output logic [191:0] o,
    output logic         wbit
);
  typedef struct packed {
    logic [3:0][7:0]  b;   // 32 bits, four 8-bit elements
    logic [1:0][15:0] h;   // 32 bits, two 16-bit elements
    logic [31:0]      w;   // 32 bits, a plain vector
  } ops_t;

  typedef struct packed {
    ops_t [1:0] ops;
  } bundle_t;

  bundle_t bn;

  always_comb begin
    bn = '0;
    bn.ops[0].b[0] = d[7:0];
    bn.ops[0].b[3] = d[31:24];
    bn.ops[0].h[1] = d[31:16];
    bn.ops[1].w    = d;
  end

  assign o = bn;
  // A plain vector member keeps BIT semantics: w[5] is one bit.
  assign wbit = bn.ops[1].w[5];
endmodule
