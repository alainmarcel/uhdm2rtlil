// Bit-select of an interface struct FIELD: sub.req.byt[N]
//   req_t.byt is a packed vector (byte enable); byt[i] selects one bit.
// Path_elems: ref(sub), ref(req), bit_select(byt[i]).  The struct-field slice
// handler covers part_select and whole-field ref_obj, not a trailing bit_select.
package p;
  typedef struct packed { logic [3:0] byt; logic [31:0] adr; } req_t;
endpackage
interface tif;
  p::req_t req;
  modport sub (input req);
  modport man (output req);
endinterface
module mem (tif.sub sub, output logic o0, output logic o3);
  assign o0 = sub.req.byt[0];
  assign o3 = sub.req.byt[3];
endmodule
module iface_struct_field_bitselect (input logic [3:0] b, output logic o0, output logic o3);
  tif s();
  assign s.req.byt = b;
  mem u (.sub(s.sub), .o0(o0), .o3(o3));
endmodule
