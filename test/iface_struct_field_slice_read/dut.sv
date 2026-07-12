// Nested struct-field SLICE read on an interface struct signal: `s.rsp.rdt[15:0]`.
// The struct-field-slice handler must resolve `rsp` to its rsp_t struct typespec
// (recorded during modport flattening) rather than re-deriving it, which can pick
// a stale/foreign typespec and leave the read unresolved (X).  Mirrors the degu
// SoC core reading the fetched instruction: dec32(tcb_ifu.rsp.rdt[32-1:0]).
package p;
  typedef struct {
    logic [31:0] rdt;
    logic [1:0]  sts;
    logic        err;
  } rsp_t;
endpackage

interface bus_if;
  import p::*;
  rsp_t rsp;
  modport man (input rsp);
endinterface

module reader (bus_if.man s, output logic [15:0] lo, output logic [15:0] hi);
  assign lo = s.rsp.rdt[15:0];
  assign hi = s.rsp.rdt[31:16];
endmodule

module top (input logic [31:0] d, output logic [15:0] lo, output logic [15:0] hi);
  import p::*;
  bus_if bus ();
  assign bus.rsp.rdt = d;
  assign bus.rsp.sts = 2'b0;
  assign bus.rsp.err = 1'b0;
  reader u (.s(bus), .lo(lo), .hi(hi));
endmodule
