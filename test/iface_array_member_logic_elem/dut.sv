// An interface UNPACKED-array member whose ELEMENT type is a plain logic
// typedef (`T din[2]`, `T res[2]` with `typedef logic [3:0] T`) -- RSD
// LoadStoreUnitIF's `dcReadData[LOAD_ISSUE_WIDTH]`, `forwardedLoadData[..]`,
// `executedLoadData[..]`.  The element geometry was only recorded for STRUCT
// elements: on the modport side the member came out at its total width with
// no element width (`p.din[i]` read ONE BIT), and on the instance side the
// member is an array_var, which the instance flattening never sized by
// element (`i.din[g]` / `i.res[g]` in the parent read and wrote one bit).
package iamlp; typedef logic [3:0] T; endpackage
interface ifc; import iamlp::*; T din [2]; T res [2]; T one [1]; T oneres [1]; logic sel; modport m(input din, one, sel, output res, oneres); endinterface
module leaf(ifc.m p);
  import iamlp::*;
  T t [2];
  always_comb begin
    for (int i = 0; i < 2; i++) t[i] = p.sel ? p.din[i] : ~p.din[i];
    p.res = t;
    // ONE-element member (RSD's LOAD_ISSUE_WIDTH = 1 lanes): `[i]` with i = 0
    // must still select the whole element, not bit 0.
    for (int i = 0; i < 1; i++) p.oneres[i] = p.one[i] + 4'd1;
  end
endmodule
module iface_array_member_logic_elem(input logic [7:0] x, input logic [3:0] o, input logic sel, output logic [7:0] y, output logic [3:0] yo);
  ifc i();
  leaf d(.p(i.m));
  for (genvar g = 0; g < 2; g++) begin : g_in
    assign i.din[g] = x[g*4 +: 4];
    assign y[g*4 +: 4] = i.res[g];
  end
  assign i.sel = sel;
  assign i.one[0] = o;
  assign yo = i.oneres[0];
endmodule
