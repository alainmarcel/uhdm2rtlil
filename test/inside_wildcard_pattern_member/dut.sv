// `inside` is a WILDCARD compare (LRM 11.4.6): an x/z/? bit of a set member
// is a don't-care.  black-parrot's cache_tagop_match_addr_gp is
// 20'('b????_????_????_??1?_????) and bp_me_dram_hash_encode decodes a tag
// operation with `paddr inside {cache_tagop_match_addr_gp}`.
package p;
  localparam dev_w = 8;
  localparam tagop  = (dev_w)'('b??1?_????);
  localparam addrop = (dev_w)'('b??0?_????);
  localparam lock   = (dev_w)'('b0001_1000);
  localparam any_v  = (dev_w)'('b????_????);
endpackage
module top import p::*; (input logic [7:0] a, output logic y1, y2, y3, y4, y5, y6);
  assign y1 = a inside {tagop};
  assign y2 = a inside {lock};
  assign y3 = a inside {tagop, lock};
  assign y4 = a inside {addrop};
  assign y5 = a inside {any_v};
  assign y6 = a inside {8'b1???_0??1, [8'h10:8'h13]};
endmodule
