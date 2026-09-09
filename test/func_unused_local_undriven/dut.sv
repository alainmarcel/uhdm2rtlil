// A function whose block-local `unused_msb` is assigned in only ONE branch
// (no else) and never read — the prim_fifo_async gray2dec pattern.  The
// function inliner left that local's initial wire undriven ("used but has no
// driver"); drive_undriven_func_locals drives it with X.  The result `dec`
// stays correct, so this test asserts BOTH equivalence and zero undriven nets.
module func_unused_local_undriven #(parameter int Depth = 8) (
  input  logic [$clog2(Depth):0] grayval,
  output logic [$clog2(Depth):0] dec);
  localparam int PTR_WIDTH = $clog2(Depth) + 1;
  function automatic [PTR_WIDTH-1:0] gray2dec(input [PTR_WIDTH-1:0] grayval);
    logic [PTR_WIDTH-1:0] dec_tmp, dec_tmp_sub;
    logic                 unused_msb;
    begin
      dec_tmp = '0;
      for (int unsigned i = PTR_WIDTH-1; i > 0; i--)
        dec_tmp[i-1] = dec_tmp[i] ^ grayval[i-1];
      dec_tmp_sub = (PTR_WIDTH)'(Depth) - dec_tmp - 1'b1;
      if (grayval[PTR_WIDTH-1]) begin
        gray2dec = dec_tmp_sub;
        gray2dec[PTR_WIDTH-1] = 1'b1;
        unused_msb = dec_tmp_sub[PTR_WIDTH-1];  // one-branch-assigned, never read
      end else begin
        gray2dec = dec_tmp;
      end
    end
  endfunction
  assign dec = gray2dec(grayval);
endmodule
