// A NAMED assignment pattern whose target's struct type the importer cannot
// see -- an interface INSTANCE member written from the parent (`p.header =
// '{ptype: i_ptype, dest: i_dest}`, read as an XMR-style child signal) and
// an element of an interface-array element's packed struct array (tnoc's
// `flit_if[0].flit[0] = '{flit_type: .., head: .., tail: .., data:
// packet_if.pack_header()}`).  Without the struct type the pattern importer
// split the target width EQUALLY among the fields (12 bits -> 6 + 6: the
// 4-bit ptype grew, the 8-bit dest lost two bits), and tnoc's header flit
// came out as three bits and 288 zeros.  A named pattern now keeps each
// field's natural width when the struct type is unknown, and the element
// writer hands the element's struct type to the pattern.
//
// UHDM-only (interfaces); test_slang_equiv.ys proves the flit and the
// header-only flag against read_slang.
package pk;
  typedef struct packed { logic [3:0] ptype; logic [7:0] dest; } common_t;
  typedef logic [11:0] packed_hdr_t;
  typedef struct packed { logic [1:0] ftype; logic head; logic tail; packed_hdr_t data; } flit_t;
  function automatic logic is_header_only(input logic [3:0] ptype);
    return ~ptype[0] & ptype[1];
  endfunction
endpackage
interface pkt_if;
  import pk::*;
  struct packed { logic [3:0] ptype; logic [7:0] dest; } header;
  logic header_valid;
  function automatic packed_hdr_t pack_header();
    common_t common_fields;
    common_fields.ptype = header.ptype;
    common_fields.dest  = header.dest;
    return packed_hdr_t'(common_fields);
  endfunction
  modport user (input header, header_valid, import pack_header);
endinterface
module ser (
  pkt_if.user  packet_if,
  output logic [15:0] o_flit,
  output logic        o_ho
);
  import pk::*;
  flit_t flit;
  logic header_only;
  always_comb begin
    header_only = is_header_only(packet_if.header.ptype);
    flit = '{ ftype: 2'd2, head: 1'b1, tail: header_only, data: packet_if.pack_header() };
  end
  assign o_flit = flit;
  assign o_ho = header_only;
endmodule
module top (
  input  logic [3:0]  i_ptype,
  input  logic [7:0]  i_dest,
  input  logic        i_valid,
  output logic [15:0] o_flit,
  output logic        o_ho
);
  pkt_if p();
  assign p.header = '{ptype: i_ptype, dest: i_dest};
  assign p.header_valid = i_valid;
  ser u_s (.packet_if(p), .o_flit(o_flit), .o_ho(o_ho));
endmodule
