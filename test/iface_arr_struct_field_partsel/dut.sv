// Array-indexed interface struct-field part-select with a computed bound —
// tcb_lite_lib_logsize2byteena's `sub.req_dly[DLY].adr[$clog2(BYT)-1:0]`.
// req_dly is driven inside the interface (`assign req_dly[0] = req`), like
// tcb_lite_if.  The consumer reads ref(sub).bit_select(req_dly[0]).part_select.
// UHDM-only: the read resolves to the correct slice `sub.req_dly[1:0]` (the
// interface-array port CONNECTION to drive it end-to-end is a separate gap).
package p;
  typedef struct packed { logic [31:0] adr; } req_t;
endpackage
interface tif;
  p::req_t req;
  p::req_t req_dly [0:0];
  assign req_dly[0] = req;
  modport sub (input req_dly);
  modport man (output req);
endinterface
module mem #(parameter int unsigned BYT = 4) (tif.sub sub, output logic [1:0] o);
  assign o = sub.req_dly[0].adr[$clog2(BYT)-1:0];   // req_dly[0].adr[1:0]
endmodule
module iface_arr_struct_field_partsel (input logic [31:0] a0, output logic [1:0] o);
  tif s();
  assign s.req.adr = a0;
  mem u (.sub(s.sub), .o(o));
endmodule
