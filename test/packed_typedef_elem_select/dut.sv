// A module variable declared through a packed-array TYPEDEF lost its element
// width, so every element select on it degenerated to a single BIT.
//
//     typedef logic [31:0] ele_t;
//     typedef ele_t [1:0]  sh_t;      // packed array of 32-bit elements
//     sh_t src, dst;
//     assign dst[1] = src[1];         // -> connect \dst [1] \src [1]
//
// One bit instead of the whole element, on BOTH sides: the read came back
// 1-bit (zero-padded to the target) and the write touched a single bit, so the
// other 31 bits of the element were left with no driver at all.
//
// `import_port` tags PORTS with packed_elem_width / packed_outer_{left,right}
// so import_bit_select can element-index them; nothing tagged plain module
// VARIABLES, so they fell back to bit selects.
//
// The tag has to cope with the TYPEDEF-ALIAS form used here: for
// `typedef ele_t [1:0] sh_t` the Elem_typespec resolves to the WHOLE array
// (its range duplicates the outer one), so get_width_from_typespec returns 64
// rather than the 32-bit element and the geometry check rightly rejects it.
// The element width is derived from the wire in that case.
//
// This is OTBN's `ma_sharing_t` (`typedef ma_ele_t [NumShares-1:0]`), which
// left otbn_mask_accelerator with 186 undriven nets and otbn_mai — which
// instantiates it — with 372.
package p;
  typedef logic [31:0] ele_t;
  typedef ele_t [1:0]  sh_t;     // packed array, 32-bit elements
  typedef logic [7:0]  small_t;
  typedef small_t [3:0] quad_t;  // 4 elements, different geometry
endpackage

module packed_typedef_elem_select (
  input  logic [63:0] r,
  input  logic [31:0] q,
  output logic [63:0] o_wr,      // element WRITES through the typedef
  output logic [31:0] o_rd,      // element READ  through the typedef
  output logic [31:0] o_quad,    // a second geometry, to catch a hard-coded width
  output logic [63:0] o_port     // a PORT-typed one: always worked (control)
);
  p::sh_t   src, dst;
  p::quad_t qd;

  assign src = r;

  // Element writes: both elements must land on their own 32 bits.
  assign dst[0] = src[0] ^ 32'hA5A5A5A5;
  assign dst[1] = src[1];

  // Element read.
  assign o_rd = src[1];

  // Different element geometry in the same module.
  assign qd[0] = q[7:0];
  assign qd[1] = q[15:8];
  assign qd[2] = q[23:16];
  assign qd[3] = q[31:24];

  assign o_wr   = dst;
  assign o_quad = qd;
  assign o_port = { src[1], src[0] };
endmodule
