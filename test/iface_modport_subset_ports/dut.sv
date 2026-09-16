// A modport that exposes only a SUBSET of its interface's signals.
//
// A module port typed `bus_if.Initiator_Ports` can see only the signals that
// modport names — the rest of the interface is not visible through it.  The
// importer created a wire per modport io_decl (correct) and then ALSO mirrored
// every signal of the interface instance on top (wrong), so the child ended up
// with ports the design does not have: `p.only_resp` and `p.sel` here, which
// belong to the Responder modport.
//
// On chipsalliance/caliptra-rtl this hit ahb_lite_bus, whose port is typed
// `CALIPTRA_AHB_LITE_BUS_INF.Initiator_Interface_Ports` (8 signals): read_uhdm
// emitted 10, adding `hsel` and `hready` from the Responder modport, while
// read_slang emitted the 8 — so the two netlists could not be paired for an
// equivalence miter at all.
//
// Both shared signals are driven from outside and read back out, so a dropped
// modport field shows up as an X on `b_out` rather than being optimised away.
interface bus_if ();
  logic [3:0] shared_a;
  logic [3:0] shared_b;
  logic [3:0] only_resp;   // Responder modport only — must NOT reach `child`
  logic       sel;         // Responder modport only — must NOT reach `child`

  modport Initiator_Ports (input shared_a, output shared_b);
  modport Responder_Ports (output shared_a, input shared_b,
                           output only_resp, sel);
endinterface

module child (bus_if.Initiator_Ports p, input logic [3:0] din);
  assign p.shared_b = p.shared_a ^ din;
endmodule

module dut (
  input  logic [3:0] din,
  input  logic [3:0] a_in,
  output logic [3:0] b_out,
  output logic [3:0] resp_out,
  output logic       sel_out
);
  bus_if bif();
  assign bif.shared_a = a_in;

  child u (.p(bif.Initiator_Ports), .din(din));

  assign b_out = bif.shared_b;

  // The Responder-only signals still exist on the interface INSTANCE (only the
  // modport-typed PORT hides them), so drive and observe them here to keep the
  // instance-level mirroring covered too.
  assign bif.only_resp = a_in + 4'd1;
  assign bif.sel       = ^a_in;
  assign resp_out      = bif.only_resp;
  assign sel_out       = bif.sel;
endmodule
