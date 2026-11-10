// A GENERIC interface port (`bus_if p`, no modport): the child DRIVES member
// `x` and READS member `c`.  The members' port directions used to be
// inherited from the interface port itself (input), so `x` became an INPUT
// the child drives; hierarchical synthesis then saw two drivers and `x` read
// X (YosysHQ/yosys#1369's `assign ifaceport.x = 1;`).  Flattening hid it.
interface bus_if;
  logic [3:0] x;
  logic [3:0] c;
endinterface

module child (input logic [3:0] k, bus_if p);
  assign p.x = p.c ^ k;
endmodule

module dut (input logic [3:0] a, k, output logic [3:0] y);
  bus_if b ();
  assign b.c = a;
  child u (.k(k), .p(b));
  assign y = b.x;
endmodule
