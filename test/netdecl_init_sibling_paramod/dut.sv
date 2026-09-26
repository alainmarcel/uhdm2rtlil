// Two instances of one child with DIFFERENT parameters, the child driving
// nets through net-declaration initialisers (`wire [3:0] t = m ? ... : x;`).
// Surelog keeps such an initialiser only on the ELABORATED instance, so
// import_module recovers them from "an elaborated instance of the same
// definition".  A $paramod imported from its own elaborated instance
// already has them; the recovery then returned the FIRST instance of the
// definition — the sibling with the other parameters — whose cont_assigns
// are different pointers, and imported its initialisers a second time:
// `i1.t` had two drivers ("Y port signal already driven" in opt), with the
// sibling's parameter values (verilog-ethernet eth_mac_1g_rgmii_fifo's
// two axis_async_fifo copies, DROP_WHEN_FULL 0 and 1).
module leaf #(
  parameter BAD  = 1'b0,
  parameter DROP = 0
) (
  input  logic       m,
  input  logic [3:0] x,
  output logic [3:0] y
);
  wire [3:0] t = m ? {4{BAD}} : x;
  wire [3:0] u = DROP ? ~t : t;
  assign y = u;
endmodule

module netdecl_init_sibling_paramod (
  input  logic       m,
  input  logic [3:0] x,
  output logic [3:0] y0,
  output logic [3:0] y1
);
  leaf #(.BAD(1'b1), .DROP(0)) i0 (.m(m), .x(x), .y(y0));
  leaf #(.BAD(1'b1), .DROP(1)) i1 (.m(m), .x(x), .y(y1));
endmodule
