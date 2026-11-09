// A function LOCAL written through a RUNTIME index, inlined into an
// always_comb arm.  CVA6 wt_dcache_mem's dcache_cl_bin2oh
// (`out = '0; out[in] = 1'b1; return out;`) is the motivating shape: the
// write was dropped ("dynamic or out-of-range select"), the function returned
// '0, and no data-bank request was ever raised outside a cache-line refill.
module dut (
    input  logic            a,
    input  logic            b,
    input  logic [1:0]      sel,
    input  logic [3:0][3:0] off,
    input  logic [3:0]      woff,
    input  logic [1:0]      v,
    input  logic [2:0]      k,
    output logic [3:0]      req,
    output logic [3:0]      we,
    output logic [7:0]      up,
    output logic [7:0]      dn,
    output logic [7:0]      ox,
    output logic [7:0]      cx
);
  function automatic logic [3:0] bin2oh(input logic [1:0] in);
    logic [3:0] out;
    out     = '0;
    out[in] = 1'b1;
    return out;
  endfunction

  // indexed part-selects with a runtime base, both directions
  function automatic logic [7:0] put_up(input logic [1:0] i, input logic [1:0] d);
    logic [7:0] r;
    r = 8'hA5;
    r[i*2 +: 2] = d;
    return r;
  endfunction

  function automatic logic [7:0] put_dn(input logic [1:0] i, input logic [1:0] d);
    logic [7:0] r;
    r = 8'h3C;
    r[i*2+1 -: 2] = d;
    return r;
  endfunction

  // compound operator, and a SELF-DETERMINED index (LRM 11.6.1): `i + 3'd6`
  // is a 3-bit sum and wraps (3 + 6 -> bit 1); evaluated at the call site's
  // 8-bit width it read 9, out of range, and the write was ignored
  function automatic logic [7:0] flip(input logic [2:0] i);
    logic [7:0] r;
    r = 8'h0F;
    r[i] ^= 1'b1;
    r[i + 3'd6] = 1'b0;
    return r;
  endfunction

  // the same function called from a CONTINUOUS assign (a second inliner)
  assign cx = flip(k);

  always_comb begin
    req = '0;
    we  = '0;
    up  = '0;
    dn  = '0;
    ox  = '0;
    if (a) begin
      req = '1;
    end else begin
      if (b) req = bin2oh(off[sel][3:2]);
      req |= bin2oh(woff[3:2]);
      we  = bin2oh(woff[3:2]);
      up  = put_up(sel, v);
      dn  = put_dn(sel, v);
      ox  = flip(k);
    end
  end
endmodule
