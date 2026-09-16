// An interface FIELD used as an instance port actual: `.a_i(p.addr)`, where
// `p` is a modport-typed interface port and `a_i` is a plain vector port.
//
// Elaboration does not keep that actual in a usable form.  Surelog rewrites
// the port's High_conn to a logic_var named after the CHILD's port
// (`work@dut.m.u.a_i.addr`), which names nothing in the instantiating module,
// so the actual imported as an EMPTY SigSpec and the port was wired to
// nothing:
//
//     cell \leaf \u
//       connect \a_i { }
//       connect \d_o { }
//
// caliptra's ahb_lite_bus feeds its address decoder exactly this way
//   .haddr_i (ahb_lite_initiator.haddr), .hwdata_i (ahb_lite_initiator.hwdata), ...
// so the decoder saw no address at all: every responder's haddr read 0 and the
// bus selected no one.  read_slang wires `\a_i \p.addr`, and the SAT miter
// caught it as a counterexample on the responders' haddr.
//
// The leaf name of that logic_var is still the interface FIELD, so the same
// unique-suffix match the importer already used for interface NETS resolves it.
//
// Both directions are covered (an input fed from a field, an output driving a
// field) and the value is observable at the top, so a dropped connection shows
// up as an X rather than being optimised away.
interface bus_if ();
  logic [7:0] addr;
  logic [7:0] rdata;
  modport Init_Ports (input addr, output rdata);
endinterface

module leaf (input logic [7:0] a_i, output logic [7:0] d_o);
  assign d_o = a_i ^ 8'hA5;
endmodule

module mid (bus_if.Init_Ports p);
  leaf u (.a_i(p.addr), .d_o(p.rdata));
endmodule

module dut (input logic [7:0] addr, output logic [7:0] rdata);
  bus_if bif();
  assign bif.addr = addr;
  mid m (.p(bif.Init_Ports));
  assign rdata = bif.rdata;
endmodule
