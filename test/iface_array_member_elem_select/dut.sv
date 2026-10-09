// An interface UNPACKED-array member (`T arr [2]`, RSD DCacheIF's
// `mshrMemMuxIn[MSHR_NUM]`) selected by element, on both sides: the parent
// wires `i.arr[g]` / `i.res[g]` in a generate loop, the modport module reads
// `p.arr[1]` and writes `p.res[0]`.  Unpatched read_uhdm imported every such
// select as ONE BIT of the flattened member (elements are 4 bits here so the
// element/bit confusion is visible).
package iamep; typedef struct packed { logic [2:0] a; logic b; } T; endpackage
interface ifc; import iamep::*; T arr [2]; T res [2]; modport m(input arr, output res); endinterface
module leaf(ifc.m p);
  assign p.res[0] = p.arr[1];
  assign p.res[1] = p.arr[0];
endmodule
module iface_array_member_elem_select(input logic [7:0] x, output logic [7:0] y);
  ifc i();
  leaf d(.p(i.m));
  for (genvar g = 0; g < 2; g++) begin : g_in
    assign i.arr[g] = x[g*4 +: 4];
    assign y[g*4 +: 4] = i.res[g];
  end
endmodule
