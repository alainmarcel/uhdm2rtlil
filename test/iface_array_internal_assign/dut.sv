// Interface ARRAY element's INTERNAL continuous assign (`assign trn = vld & rdy`)
// must be imported per element.  Mirrors degu SoC tcb_lite_if `assign trn =
// vld & rdy` on the `tcb_per [2-1:0]` array: for a single interface it is driven,
// for array elements it was left UNDRIVEN -> sys_wen = wen & X -> no GPIO write.
interface tif;
  logic vld, rdy, trn;
  assign trn = vld & rdy;
  modport sub (input vld, input rdy, input trn);
endinterface

module sink (input logic trn, output logic o);
  assign o = trn;
endmodule

module iface_array_internal_assign
  (input logic v0, input logic r0, input logic v1, input logic r1,
   output logic o0, output logic o1);
  tif s [2-1:0] ();
  assign s[0].vld = v0;  assign s[0].rdy = r0;
  assign s[1].vld = v1;  assign s[1].rdy = r1;
  sink u0 (.trn(s[0].trn), .o(o0));
  sink u1 (.trn(s[1].trn), .o(o1));
endmodule
