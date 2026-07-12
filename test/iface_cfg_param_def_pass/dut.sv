// Interface struct-parameter override resolution through the actual connection.
// A device reads an interface struct parameter (`s.CFG.DAT`).  The modport-parent
// port copy reached from the reference is often a value-less / DEFAULT stub, so
// the read must resolve through the port's High_conn (the actual connected
// interface instance carrying the override) rather than falling back to the
// interface's default.  Mirrors the degu SoC peripheral device modules; the
// same path (via an elaborated instance) also silences the standalone
// AllModules def-pass import that otherwise reports a spurious unresolved read.
package p;
  typedef struct packed { int unsigned DAT; } cfg_t;
endpackage

interface bus_if #(parameter p::cfg_t CFG = '{DAT: 8});
  logic [CFG.DAT-1:0] data;
  modport mp (input data);
endinterface

module reader (bus_if.mp s, output logic [31:0] w);
  assign w = 32'(s.CFG.DAT);   // must be the override (24), not the default (8)
endmodule

module top (output logic [31:0] w);
  localparam p::cfg_t C24 = '{DAT: 24};
  bus_if #(C24) bus ();
  reader u (.s(bus), .w(w));
endmodule
