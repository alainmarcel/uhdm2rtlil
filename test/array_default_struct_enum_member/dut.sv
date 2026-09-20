// `'{default: <struct>}` on an unpacked ARRAY of structs filled the struct's
// MEMBERS instead of the array's ELEMENTS, as soon as the struct carried an
// ENUM member.
//
//     typedef struct packed { logic [1:0] f; sel_e e; } d_t;  // 4 bits
//     localparam d_t Def = '{f: 2'b01, e: SelC};              // 4'b0110
//     d_t ae[4];
//     ae = '{default: Def};   ->  4'1010, once, zero-extended
//
// Each MEMBER got Def truncated to that member's 2-bit width -- low bits of
// 0110 = 10 -- so the result was {10,10} = 4'1010 for ONE element, and the
// array's other three elements were left at zero.  Every element should read
// Def = 4'b0110.
//
// Root cause: with no typespec on the pattern op, the importer recovers the
// target type from the assignment LHS, accepting any struct/union.  For an
// unpacked-array target Surelog hands back the ELEMENT struct -- which it only
// does once a member is an ENUM, hence the enum sensitivity -- so the
// struct-member fill path claimed an array target.  The fix: when the target
// context is a whole multiple of that struct, the target is an ARRAY of it, so
// fall through to the element fill.
//
// This is OTBN's PredecDynDefault (`mul_op_a_tmp_sel: 1'b1` is its one
// non-zero field, which is exactly what got lost); it cut
// otbn_mac_bignum_fsm's co-sim divergences from 168 to 97.
//
// `o_plain` is the no-enum control.  `o_member` is the REGRESSION GUARD for
// the behaviour this fix must NOT break: `'{default: V}` on a genuine STRUCT
// target still fills that struct's members.
module array_default_struct_enum_member (
  input  logic [1:0] i,
  input  logic       r,
  output logic [3:0] o_enum,     // array of enum-bearing struct
  output logic [3:0] o_plain,    // array of plain struct (control)
  output logic [3:0] o_2d,       // 2-D array of enum-bearing struct
  output logic [3:0] o_member,   // genuine struct target (must fill MEMBERS)
  output logic [3:0] o_named     // named tag + default on a struct target
);
  typedef enum logic [1:0] { SelA = 2'b00, SelB = 2'b01, SelC = 2'b10 } sel_e;

  typedef struct packed { logic [1:0] f; sel_e       e; } d_t;
  typedef struct packed { logic [1:0] f; logic [1:0] e; } p_t;

  // Both fields non-zero, and DIFFERENT from each other: a member-wise fill
  // (which truncates Def to each member) then cannot coincide with the right
  // answer.
  localparam d_t Def  = '{f: 2'b01, e: SelC};    // 4'b0110
  localparam p_t PDef = '{f: 2'b01, e: 2'b10};   // 4'b0110

  d_t ae[4];
  p_t ap[4];
  d_t a2[2][2];

  always_comb begin
    ae = '{default: Def};
    ap = '{default: PDef};
    a2[0] = '{default: Def};
    a2[1] = '{default: Def};
  end

  assign o_enum  = ae[i];
  assign o_plain = ap[i];
  assign o_2d    = a2[i[1]][i[0]];

  // A genuine STRUCT target: '{default: 1'b1} must set EVERY member to 1
  // (each 2-bit member becomes 2'b01), not do an element fill.  These two use
  // the PLAIN struct: a scalar default against an enum member is not legal SV
  // (slang rightly rejects the implicit bit -> enum conversion).
  p_t s_all;
  always_comb s_all = '{default: 1'b1};
  assign o_member = s_all;

  // Named tag beside the default, still on a struct target: f takes the named
  // value, e takes the default.
  p_t s_named;
  always_comb s_named = r ? '{f: 2'b10, default: 1'b0} : '{f: 2'b01, default: 1'b1};
  assign o_named = s_named;
endmodule
