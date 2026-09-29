// `return '{known: .., bytes: ..}` from a struct-returning function called in
// an always_comb: the anonymous pattern has no typespec of its own and the
// comb inliner threaded only the return WIDTH, so every field was sized to
// width/count -- 8/2 = 4 bits apiece for {logic; logic [6:0]} -- packing
// {4'b0001, 4'd4} = 8'h14 where the RTL means {1'b1, 7'd4} = 8'h84.  The same
// call from a continuous assign happened to keep the fields' natural widths.
// The return struct is now the pattern's context typespec on both paths.
package p;
  typedef struct packed { logic known; logic [6:0] bytes; } meta_t;
  typedef struct packed { logic [2:0] tag; logic v; logic [11:0] len; } wide_t;
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
    return '{known: (c == 8'h22) | (c == 8'h28), bytes: nbytes(c)};
  endfunction
  function automatic wide_t mkw(input logic [7:0] c);
    return '{tag: c[2:0], v: c[7], len: {4'h0, c}};
  endfunction
endpackage

module dut (
  input  logic [7:0]  c,
  output p::meta_t    m_assign,
  output p::meta_t    m_comb,
  output logic [7:0]  m_comb_flat,
  output p::wide_t    w_assign,
  output p::wide_t    w_comb
);
  assign      m_assign    = p::mk(c);
  always_comb m_comb      = p::mk(c);
  always_comb m_comb_flat = p::mk(c);
  assign      w_assign    = p::mkw(c);
  always_comb w_comb      = p::mkw(c);
endmodule
