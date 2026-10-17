// IEEE 1800-2017 5.7.1: a sized literal whose leftmost digit is x, z or `?`
// is extended with that digit.  black-parrot binds a register decoder with
// `.base_addr_p({64'b????????????????})` -- sixteen wildcard digits in a
// 64-bit literal, meaning EVERY address; zero-extended it matched only the
// low 64 KiB (bp_sacc_vdp).  A leftmost 0/1 digit still zero-extends.
module top (input logic [63:0] a, input logic [7:0] b, output logic y1, y2, y3, output logic [1:0] y4);
  localparam [63:0] P = 64'b????????????????;
  localparam [63:0] Q = 64'b1???????????????;
  localparam [7:0]  R = 8'h?;
  assign y1 = a inside {P};
  assign y2 = a inside {Q};
  assign y3 = b inside {R};
  always_comb
    unique casez (b)
      8'b1???_????: y4 = 2'd1;
      8'b01??_????: y4 = 2'd2;
      default:      y4 = 2'd0;
    endcase
endmodule
