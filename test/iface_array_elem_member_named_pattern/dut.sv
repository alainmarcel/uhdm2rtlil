// a NAMED assignment pattern with UNSIZED fills (`'0`) onto a struct member of
// an interface-ARRAY ELEMENT (`error_packet_if[1].header = '{packet_type: t,
// ..., address: '0, ...}`, tnoc_error_checker): with no struct type for the
// target each value kept its own width, a fill became one bit, and every field
// above it landed at the wrong offset -- the response packet type's top bit
// was lost and the serializer never saw a header-only packet.
interface types;
  typedef struct packed { logic [7:0] packet_type; logic [3:0] vc; logic inv; logic [15:0] address; logic [1:0] status; } hdr_t;
endinterface
interface pif (types t);
  typedef t.hdr_t hdr_t;
  hdr_t header;
  logic  header_valid;
endinterface
module top (input logic [7:0] pt, input logic [3:0] vc, input logic [1:0] st, output logic [30:0] h0, output logic [30:0] h1);
  types t();
  pif p[2](t);
  always_comb begin
    p[0].header = '{packet_type: pt, vc: vc, inv: '0, address: '0, status: st};
    p[1].header = '{packet_type: 8'h80 | pt, vc: vc, inv: '1, address: '0, status: st};
  end
  assign h0 = p[0].header;
  assign h1 = p[1].header;
endmodule
