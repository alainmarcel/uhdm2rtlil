// hpdcache_mshr ENTRY_BITS shape: $bits of a struct whose member typedefs
// take their widths from fields of a >64-bit struct parameter.
package bcs_pkg;
  typedef struct packed {
    int unsigned pad0;
    int unsigned pad1;
    int unsigned tagWidth;
    int unsigned idWidth;
  } cfg_t;
  localparam cfg_t Cfg = '{pad0: 1, pad1: 2, tagWidth: 44, idWidth: 5};
endpackage

module bits_cfg_struct #(
  parameter bcs_pkg::cfg_t K = bcs_pkg::Cfg
) (
  output logic [31:0] nbits_o
);
  typedef logic [K.tagWidth-1:0] tag_t;
  typedef logic [K.idWidth-1:0]  id_t;
  typedef struct packed {
    tag_t tag;
    id_t  req_id;
    logic need_rsp;
  } entry_t;
  localparam int unsigned ENTRY_BITS = $bits(entry_t);
  assign nbits_o = ENTRY_BITS;
endmodule
