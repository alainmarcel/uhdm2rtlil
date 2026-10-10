// `p.arr[i].regTag[j].num` -- an interface UNPACKED-array member of packed
// structs whose field is a PACKED array of structs, then a field of that
// element (RSD WakeupLogic: `port.writeSrcTag[i].regTag[j].num`).
package wkp;
  typedef struct packed { logic [5:0] num; logic valid; } R;
  typedef struct packed { R [2:0] regTag; logic [1:0] ptr; } T;
endpackage
interface ifc; import wkp::*; T arr [2]; logic [35:0] num; logic [5:0] valid; modport m(input arr, output num, valid); endinterface
module leaf(ifc.m p);
  always_comb begin
    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++) begin
        p.num[(i*3+j)*6 +: 6] = p.arr[i].regTag[j].num;
        p.valid[i*3+j]        = p.arr[i].regTag[j].valid;
      end
  end
endmodule
module iface_array_member_nested_elem_field(input logic [45:0] arr_flat, output logic [35:0] num_flat, output logic [5:0] valid_flat);
  ifc i();
  leaf d(.p(i.m));
  for (genvar g = 0; g < 2; g++) begin : g_in
    assign i.arr[g] = arr_flat[g*23 +: 23];
  end
  assign num_flat = i.num; assign valid_flat = i.valid;
endmodule
