// `p.arr[s].a` -- a DYNAMIC element of an interface UNPACKED-array member of
// packed structs, then a field (RSD DCacheMemoryReqPortMultiplexer:
// `port.mshrMemMuxIn[portIn].addr`).  Unpatched read_uhdm resolved nothing
// and the outputs were constant X.
package iamdp; typedef struct packed { logic [2:0] a; logic b; } T; endpackage
interface ifc; import iamdp::*; T arr [2]; logic sel; logic [2:0] a; logic b; modport m(input arr, sel, output a, b); endinterface
module leaf(ifc.m p);
  logic s;
  always_comb begin s = p.sel; p.a = p.arr[s].a; p.b = p.arr[s].b; end
endmodule
module iface_array_member_dyn_field(input logic [7:0] arr_flat, input logic sel, output logic [2:0] a, output logic b);
  ifc i();
  leaf d(.p(i.m));
  for (genvar g = 0; g < 2; g++) begin : g_in
    assign i.arr[g] = arr_flat[g*4 +: 4];
  end
  assign i.sel = sel; assign a = i.a; assign b = i.b;
endmodule
