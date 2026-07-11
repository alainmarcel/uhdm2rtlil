// Whole-field read of an array-indexed interface struct field (no part-select):
//   sub.req_dly[DLY].siz   (tcb_lite_lib_logsize2byteena reads .siz/.ndn this way)
// Path_elems: ref(sub), bit_select(req_dly[0]), ref(siz).  The existing
// struct-field-partsel handler only fires when the last elem is a part_select.
package p;
  typedef struct packed { logic [1:0] siz; logic [31:0] adr; } req_t;
endpackage
interface tif;
  p::req_t req;
  p::req_t req_dly [0:0];
  assign req_dly[0] = req;
  modport sub (input req_dly);
  modport man (output req);
endinterface
module mem (tif.sub sub, output logic [1:0] o);
  assign o = sub.req_dly[0].siz;      // whole 2-bit field
endmodule
module iface_arr_struct_whole_field (input logic [1:0] s0, output logic [1:0] o);
  tif s();
  assign s.req.siz = s0;
  mem u (.sub(s.sub), .o(o));
endmodule
