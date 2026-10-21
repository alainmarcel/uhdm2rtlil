// A packed array whose ELEMENT TYPE IS A TYPE PARAMETER bound to a packed
// 2-D typedef, written with a three-level index.
//
// The geometry stamped at declaration carries outer + element + leaf -- three
// numbers, i.e. two index levels.  `arr[i][j][k]` needs FOUR (outer stride,
// middle, leaf, bit), so the last index fell through to the bit-select path
// and wrote ONE BIT instead of a whole leaf word: 4 one-bit connects out of
// 32 bits, 28 of them left with no driver.
//
// CVA6's hpdcache_memctrl is this shape (`hpdcache_req_data_t
// [RATIO-1:0][ways-1:0] data_read_words`, the type a parameter), in code the
// default configuration never instantiates.
module packed_typeparam_elem_three_levels #(
  parameter int RATIO = 1,
  parameter int WAYS  = 2,
  parameter int WORDS = 2,
  parameter type elem_t = logic
)(
  input  logic [RATIO*WAYS*WORDS*8-1:0] src,
  output logic [RATIO*WAYS*WORDS*8-1:0] dst
);
  elem_t [RATIO-1:0][WAYS-1:0] arr;
  for (genvar i = 0; i < RATIO; i++)
    for (genvar j = 0; j < WAYS; j++)
      for (genvar k = 0; k < WORDS; k++)
        assign arr[i][j][k] = src[((i*WAYS+j)*WORDS+k)*8 +: 8];
  assign dst = arr;
endmodule

module top (input logic [31:0] src, output logic [31:0] dst);
  typedef logic [1:0][7:0] word_t;
  packed_typeparam_elem_three_levels #(
    .RATIO(1), .WAYS(2), .WORDS(2), .elem_t(word_t)
  ) u (.src(src), .dst(dst));
endmodule
