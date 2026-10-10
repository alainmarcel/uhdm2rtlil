// A ONE-element interface array member whose element is a PACKED STRUCT
// (`PhyAddrPath executedLoadAddr[LOAD_ISSUE_WIDTH]` with LOAD_ISSUE_WIDTH = 1
// in RSD's LoadStoreUnitIF; PhyAddrPath is a 22-bit packed struct).  The
// modport flattening found the element struct type first and then SKIPPED the
// array-geometry search, which only ran when no struct was known, so a
// one-element struct array had no element geometry: `port.m[i]` with i = 0
// read ONE BIT (the load address register captured bit 0 and every load took
// its data from byte 0 of the cache line).
package iamso;
  typedef struct packed { logic uncachable; logic io; logic [19:0] addr; } PhyAddrPath;
endpackage
interface ifc(input logic clk, rst);
  import iamso::*;
  PhyAddrPath a [1];
  logic [21:0] q [1];
  modport m(input clk, rst, a, output q);
endinterface
module leaf(ifc.m p);
  import iamso::*;
  PhyAddrPath aReg [1];
  always_ff @(posedge p.clk) begin
    for (int i = 0; i < 1; i++) begin
      if (p.rst) aReg[i] <= '0;
      else aReg[i] <= p.a[i];
    end
  end
  always_comb begin
    for (int i = 0; i < 1; i++) p.q[i] = aReg[i] ^ {aReg[i].io, aReg[i].uncachable, aReg[i].addr};
  end
endmodule
module iface_array_member_struct_one(input logic clk, input logic rst, input logic [21:0] a, output logic [21:0] y);
  ifc i(.clk(clk), .rst(rst));
  leaf d(.p(i.m));
  assign i.a[0] = a;
  assign y = i.q[0];
endmodule
