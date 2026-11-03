// A comparison's operands are sized to max(self-size(L), self-size(R)) and
// an UNSIZED literal is 32 bits (LRM 5.7.1, 11.6.1).  With the literal nested
// in a sub-expression (`(ll+1)*8`) read_uhdm sized it at Surelog's 64 bits,
// so `fs + fsz` was evaluated at 64 bits, never wrapped, and the compare
// took the wrong branch -- cheshire's axi_vga_fetcher frame-end test
// `req_addr_q >= frame_start_q + frame_size_q - ((last_len_q+1)*AXIStrbWidth)`.
module dut(input logic [31:0] ra, input logic [31:0] fs, input logic [31:0] fsz, input logic [7:0] ll,
           output logic ge_param, output logic ge_lit, output logic ge_nolit, output logic [31:0] sum);
  localparam int unsigned W = 8;
  assign ge_param = ra >= fs + fsz - ((ll+1)*W);
  assign ge_lit   = ra >= fs + fsz - ((ll+1)*8);
  assign ge_nolit = ra >= fs + fsz - (ll*W);
  assign sum      = fs + fsz - ((ll+1)*W);
endmodule
