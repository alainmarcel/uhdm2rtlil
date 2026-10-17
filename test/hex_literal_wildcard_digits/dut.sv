// `?` in a HEX literal is the alternative spelling of z (IEEE 1800-2017
// 5.7.1); as a set member of `inside` it is a wildcard nibble.  black-parrot
// writes its address-match patterns that way (`20'h0_8???`); the hex parser
// knew x and z digits and read `?` as 0, so the pattern matched one address.
// (A packed TABLE `{UCODE, FREEZE}` of such patterns is folded by Surelog with
// the `?` digits lost, so it cannot be part of this reader test.)
package p;
  localparam dev_w = 20;
  localparam [dev_w-1:0] UCODE = 20'h0_8???;
  localparam [dev_w-1:0] FREEZE = 20'h0_0008;
  localparam [dev_w-1:0] TAGOP = 20'b????_????_????_??1?_????;
endpackage
module top import p::*; (input logic [19:0] a, output logic y1, y2, y3);
  assign y1 = a inside {UCODE};
  assign y2 = a inside {FREEZE};
  assign y3 = a inside {TAGOP};
endmodule
