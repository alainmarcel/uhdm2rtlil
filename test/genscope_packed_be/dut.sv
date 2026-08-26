// hpdcache_mshr byte-enable shape: inside a GENERATE scope, a packed array
// whose element type is a local TYPEDEF, written per-element with an unbased
// unsized fill (`be[i] = '1`).  The element geometry has to come from the
// declared outer range — otherwise `'1` sets a single BIT per element and
// only one byte of each RAM word is ever enabled.
module genscope_packed_be #(
    parameter int unsigned WAYS = 2,
    parameter int unsigned WORD_BITS = 64
) (
    input  logic [$clog2(WAYS)-1:0]      sel_i,
    output logic [WAYS*WORD_BITS/8-1:0]  be_o
);
  typedef logic [WORD_BITS/8-1:0] be_t;

  if (WAYS > 1) begin : gen_be
    be_t [WAYS-1:0] be;

    always_comb begin
      for (int unsigned i = 0; i < WAYS; i++) begin
        be[i] = (32'(sel_i) == i) ? '1 : '0;
      end
    end

    assign be_o = be;
  end
endmodule
