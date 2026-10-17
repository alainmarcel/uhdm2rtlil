// A VOID interface method called through a PORT as a STATEMENT that WRITES
// the port's members (`packet_if.unpack_header(data)` in tnoc's packet
// deserializer).  The interface is parameterised and takes an interface
// port of its own (tnoc_packet_if(types)); by the time the child's
// always_comb is imported its `\pkt` placeholder wire is gone, and the call
// was skipped ("Method func call 'unpack_header' has no Function()").  The
// interface must be recovered from the UHDM port itself.
interface types;
  typedef logic [7:0] dest_t;
  typedef logic [3:0] ptype_t;
endinterface

interface packet_if #(parameter int DW = 4) (types t);
  typedef t.dest_t  dest_t;
  typedef t.ptype_t ptype_t;
  typedef struct packed { ptype_t ptype; dest_t dest; } hdr_t;
  hdr_t   header;
  logic   valid;
  function automatic void unpack_header(logic [11:0] data);
    hdr_t tmp;
    tmp = hdr_t'(data);
    header.ptype = tmp.ptype;
    header.dest  = tmp.dest;
  endfunction
  function automatic logic get_ack(); return valid; endfunction
  modport master (output header, output valid, import unpack_header, import get_ack);
endinterface

module child (types t, packet_if.master pkt, input logic [11:0] flit, input logic v);
  always_comb begin
    pkt.valid = v;
    pkt.unpack_header(flit);
  end
endmodule

module top (input logic [11:0] flit, input logic v, output logic [3:0] ptype, output logic [7:0] dest, output logic ack);
  types ty();
  packet_if #(.DW(8)) p(ty);
  child c (.t(ty), .pkt(p.master), .flit(flit), .v(v));
  assign ptype = p.header.ptype;
  assign dest  = p.header.dest;
  assign ack   = p.get_ack();
endmodule
