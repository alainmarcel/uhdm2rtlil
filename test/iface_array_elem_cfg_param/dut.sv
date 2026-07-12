// Interface-ARRAY-ELEMENT struct-parameter resolution: a child connects its
// interface port to an array element `.s(arr[0])` (a bit_select).  Reading a
// struct parameter field of that interface (`s.CFG.DAT`) must follow the
// bit_select High_conn to the valued array-element instance; the port-copy
// interface is a value-less / default stub, so without that the read resolves
// to the wrong (default) value.  Mirrors the degu SoC converters connected to
// tcb_lsd[i] / tcb_per[i].  The reader is parameterized so it is elaborated
// per-instance (with instance context), matching those paramod converters.
package p;
  typedef struct packed { int unsigned DAT; } cfg_t;
endpackage

interface bus_if #(parameter p::cfg_t CFG = '{DAT: 8});
  logic [CFG.DAT-1:0] data;
  modport mp (input data);
endinterface

module reader #(parameter int ID = 0) (bus_if.mp s, output logic [31:0] w);
  assign w = 32'(s.CFG.DAT) + ID;   // struct-param field of an array-element iface
endmodule

module top (output logic [31:0] w);
  localparam p::cfg_t C16 = '{DAT: 16};
  bus_if #(C16) arr [2-1:0] ();
  reader #(.ID(0)) u (.s(arr[0]), .w(w));   // connect to array ELEMENT (bit_select)
endmodule
