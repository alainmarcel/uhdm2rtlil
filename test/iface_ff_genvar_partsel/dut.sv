// always_ff LHS = interface STRUCT-member indexed part-select with a
// genvar-arithmetic base `sub.req.wdt[i*8+:8]` inside an unrolled loop — the
// jeras/rp32 tcb_lite_lib_register_request write-data reshaping loop.
package p;
  typedef struct packed { logic [31:0] wdt; } req_t;
endpackage
interface bus_if #(parameter int BYT = 4);
  import p::*;
  logic clk;
  req_t req;
  logic [31:0] src;
endinterface
module child (bus_if sub);
  generate
    for (genvar i = 0; i < 4; i++) begin : g
      always_ff @(posedge sub.clk)
        sub.req.wdt[i*8 +: 8] <= sub.src[i*8 +: 8];
    end
  endgenerate
endmodule
module top (input logic clk, input logic [31:0] s, output logic [31:0] o);
  bus_if #(.BYT(4)) sub ();
  assign sub.clk = clk;
  assign sub.src = s;
  assign o = sub.req.wdt;
  child c (.sub(sub));
endmodule
