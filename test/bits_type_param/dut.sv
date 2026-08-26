// hpdcache_mshr ENTRY_BITS: $bits of a struct whose members are
// PARAMETER TYPES (default logic), overridden at instantiation.
module btp_leaf #(
  parameter type tag_t = logic,
  parameter type id_t  = logic
) (
  output logic [31:0] nbits_o,
  output tag_t        tag_o
);
  typedef struct packed {
    tag_t tag;
    id_t  req_id;
    logic need_rsp;
  } entry_t;
  localparam int unsigned ENTRY_BITS = $bits(entry_t);
  assign nbits_o = ENTRY_BITS;
  assign tag_o = '1;
endmodule

module bits_type_param (
  output logic [31:0] nbits_o,
  output logic [43:0] tag_o
);
  btp_leaf #(
    .tag_t(logic [43:0]),
    .id_t (logic [4:0])
  ) u (.nbits_o(nbits_o), .tag_o(tag_o));
endmodule
