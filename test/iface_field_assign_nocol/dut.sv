// Continuous assignment to an interface struct FIELD in the parent:
// `assign s.req.adr = a_i;`  The LHS is a hier_path (iface s -> field req ->
// subfield adr).  These assigns drive slices of the packed `req` struct wire;
// if dropped, the interface signal is undriven and the consumer reads X.
interface tcb_if;
  typedef struct packed {
    logic [7:0]  adr;
    logic [31:0] wdt;
    logic        wen;
  } req_t;
  req_t        req;
  logic [31:0] rsp;
  modport sub (input req, output rsp);
endinterface

module dev (input logic clk, tcb_if.sub s);
  always_ff @(posedge clk)
    s.rsp <= s.req.wen ? (s.req.wdt + {24'b0, s.req.adr}) : s.rsp;
endmodule

module iface_field_assign_nocol (
  input  logic        clk,
  input  logic [7:0]  a_i,
  input  logic [31:0] d_i,
  input  logic        e_i,
  output logic [31:0] rsp
);
  tcb_if s();
  assign s.req.adr = a_i;
  assign s.req.wdt = d_i;
  assign s.req.wen = e_i;
  assign rsp       = s.rsp;
  dev u_dev (.clk(clk), .s(s.sub));
endmodule
