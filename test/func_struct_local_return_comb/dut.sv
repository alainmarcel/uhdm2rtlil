// A function that assembles a packed STRUCT local member by member and returns
// it (`m.known = ...; m.bytes = ...; return m;`) gave X when called from an
// always_comb: the comb inliner only knew the `acc[k].field` array form, so
// each member write fell to the generic path under a name that is no mapping
// key and the local stayed Sx.  The same call from a continuous assign was
// right (the assign path walks the struct), which is what hid it.  usb2's
// ocp_response_meta() in caliptra-ss usb_ocp_recovery_ctrl_decode: every
// SETUP decode read the response length / known flag as X.
package p;
  typedef struct packed { logic known; logic [6:0] bytes; } meta_t;
  function automatic logic [6:0] nbytes(input logic [7:0] c);
    logic [6:0] b;
    case (c)
      8'h22: b = 7'd15;
      8'h28: b = 7'd4;
      default: b = 7'd0;
    endcase
    return b;
  endfunction
  function automatic meta_t mk(input logic [7:0] c);
    meta_t m;
    begin
      m.known = (c == 8'h22) | (c == 8'h28);
      m.bytes = nbytes(c);
      return m;
    end
  endfunction
endpackage

module dut (
  input  logic [7:0] c,
  output p::meta_t   m_assign,
  output p::meta_t   m_comb,
  output p::meta_t   m_local,
  output logic [7:0] m_comb_flat
);
  function automatic p::meta_t mkl(input logic [7:0] c);
    p::meta_t m;
    begin
      m.known = (c == 8'h22) | (c == 8'h28);
      m.bytes = p::nbytes(c);
      return m;
    end
  endfunction
  assign      m_assign    = p::mk(c);
  always_comb m_comb      = p::mk(c);
  always_comb m_local     = mkl(c);
  always_comb m_comb_flat = p::mk(c);
endmodule
