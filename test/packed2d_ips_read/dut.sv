// hpdcache_mshr's RAM unpack shape: a typedef'd PACKED 2-D array read with a
// trailing constant indexed part-select — `rdata[i][0 +: ENTRY_BITS]`.  The
// element type comes from a typedef (so the var's own Ranges() hold the outer
// dimension and its typespec describes the element), and the trailing `+:`
// selects the used sub-field of each RAM word.
module packed2d_ips_read #(
    parameter int unsigned WAYS = 2,
    parameter int unsigned RAM_BITS = 16,
    parameter int unsigned ENTRY_BITS = 10
) (
    input  logic [WAYS*RAM_BITS-1:0] flat_i,
    output logic [ENTRY_BITS-1:0]    e0_o,
    output logic [ENTRY_BITS-1:0]    e1_o
);
  typedef logic [RAM_BITS-1:0] ram_word_t;
  ram_word_t [WAYS-1:0] rdata;

  assign rdata = flat_i;

  // Trailing indexed part-select on a packed 2-D element.
  assign e0_o = rdata[0][0+:ENTRY_BITS];
  assign e1_o = rdata[1][0+:ENTRY_BITS];
endmodule
