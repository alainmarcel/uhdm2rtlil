// Bit-select of a packed-struct FUNCTION ARGUMENT's member, inside a loop:
// Caliptra's sha512_masked_defines_pkg B2A_conv / A2B_conv walk the 64 bits of
// a `masked_reg_t` argument as `x.masked[j]` / `x.random[j]`.
//
// Path_elems for `x.masked[j]` are [ref_obj x, bit_select masked] -- the
// trailing bit_select IS the member (its VpiName is `masked`), it just also
// carries an index.  The general struct-member-chain resolver required EVERY
// path element to be a plain ref_obj, so this shape fell through to X: in the
// chip both masked SHA-512 cores (hmac.hmac_inst.core.u_sha512_core_h1 and
// ecc_top1...hmac_drbg_i.HMAC_K.u_sha512_core_h1) computed their
// boolean<->arithmetic mask conversions on unknowns -- 5568 `x.masked[N]` and
// 2304 `x.random[N]` unresolved reads.
package p;
  typedef struct packed {
    reg [7:0] masked;
    reg [7:0] random;
  } m_t;

  // Non-zero declared LSB, to catch a selector that forgets to rebase.
  typedef struct packed {
    reg [11:4] hi;
    reg [3:0]  lo;
  } off_t;

  // The B2A_conv shape: a ripple over the bits of a struct-arg member.
  function automatic m_t b2a (input m_t x, input logic q);
    reg [7:0] carry;
    reg [7:0] xp;
    for (int j = 0; j < 8; j++) begin
      if (j == 0) begin
        carry[j] = ~x.masked[j] & (x.random[j] ^ q) | (x.masked[j] & q);
        xp[j]    = x.masked[j];
      end else begin
        carry[j] = ~x.masked[j] & (x.random[j] ^ q) | x.masked[j] & carry[j-1];
        xp[j]    = (x.masked[j] ^ carry[j-1]) ^ q;
      end
    end
    return {xp, x.random};
  endfunction

  // Trailing PART-select on a struct-arg member.
  function automatic reg [3:0] nib (input m_t x);
    return x.masked[7:4] ^ x.random[3:0];
  endfunction

  // Trailing bit-select on a member whose declared range does not start at 0.
  function automatic reg [1:0] hibits (input off_t o);
    return {o.hi[11], o.lo[3]};
  endfunction

  // Dynamic (non-constant) bit index into a struct-arg member.
  function automatic reg dynbit (input m_t x, input logic [2:0] s);
    return x.masked[s];
  endfunction
endpackage

module func_struct_arg_member_bitsel (
  input  p::m_t       a,
  input  logic        q,
  input  p::off_t     o,
  input  logic [2:0]  s,
  output p::m_t       y,
  output logic [3:0]  n,
  output logic [1:0]  h,
  output logic        d
);
  assign y = p::b2a(a, q);
  assign n = p::nib(a);
  assign h = p::hibits(o);
  assign d = p::dynbit(a, s);
endmodule


// NOTE: an element select on a PACKED-ARRAY member of a runtime struct arg
// (`b.blk[k]` where `blk` is `reg [2:0][7:0]`) is a SEPARATE, pre-existing bug
// -- it miters NON-EQUIVALENT against read_slang on plain main and emits no
// warning at all, so it is not covered here.  test/struct_param_func_loop
// covers the constant-argument form of that shape (`C.base[k]`), which works
// and which the fix under test must not disturb.
