// Interface struct with a parameter-computed ZERO-WIDTH field (CTL=0, STS=0):
// `logic [BUS.CTL-1:0] ctl` folds to `[-1:0]` -> width 0.  Passthrough modules
// copy the whole struct field-by-field, including the empty fields
// (`man.req.ctl = sub.req.ctl`, `sub.rsp.sts = '0`).  Exercises 0-width struct
// member access on both sides of a continuous assignment (read + no-op write).
package p;
  typedef struct { int unsigned CTL; int unsigned DAT; int unsigned STS; } bus_t;
  localparam bus_t B = '{CTL:0, DAT:8, STS:0};
  typedef struct packed {
    logic              wen;
    logic [B.CTL-1:0]  ctl;   // ZERO width
    logic [B.DAT-1:0]  wdt;
  } req_t;
  typedef struct packed {
    logic [B.DAT-1:0]  rdt;
    logic [B.STS-1:0]  sts;   // ZERO width
  } rsp_t;
endpackage

interface my_if import p::*; (input logic clk);
  req_t req;
  rsp_t rsp;
  modport sub (input clk, input  req, output rsp);
  modport man (input clk, output req, input  rsp);
endinterface

// Passthrough: copies every field, including the empty ctl/sts.
module pass import p::*; (my_if.sub sub, my_if.man man);
  assign man.req.wen = sub.req.wen;
  assign man.req.ctl = sub.req.ctl;   // 0-width no-op
  assign man.req.wdt = sub.req.wdt;
  assign sub.rsp.rdt = man.rsp.rdt;
  assign sub.rsp.sts = man.rsp.sts;   // 0-width no-op
endmodule

module top import p::*; (
  input  logic       clk,
  input  logic       in_wen,
  input  logic [7:0] in_wdt,
  input  logic [7:0] mem_rdt,
  output logic       out_wen,
  output logic [7:0] out_wdt,
  output logic [7:0] out_rdt
);
  my_if a (.clk(clk));
  my_if b (.clk(clk));
  assign a.req.wen = in_wen;
  assign a.req.wdt = in_wdt;
  assign b.rsp.rdt = mem_rdt;
  pass u (.sub(a), .man(b));
  // observe the manager-side request and the subordinate-side response
  assign out_wen = b.req.wen;
  assign out_wdt = b.req.wdt;
  assign out_rdt = a.rsp.rdt;
endmodule
