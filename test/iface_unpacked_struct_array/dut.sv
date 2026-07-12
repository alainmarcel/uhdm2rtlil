// Interface with an UNPACKED array of a packed STRUCT, sized by a parameter.
// Surelog's elaborated interface DEFINITION collapses `pkt_t dly [0:DLY]` to a
// bare element-width net (dropping the [0:DLY] dimension); only the elaborated
// interface INSTANCE keeps it as an array_net.  A child module reading the
// delayed element `s.dly[1].a` must see a 2-element (32-bit) flattened wire, or
// the read falls out of bounds and resolves to X.
package p;
  typedef struct packed {
    logic [7:0] a;
    logic [7:0] b;
  } pkt_t;
endpackage

interface bus_if #(parameter int DLY = 1) (input logic clk);
  import p::*;
  pkt_t in;
  pkt_t dly [0:DLY];
  assign dly[0] = in;
  generate
    for (genvar i = 1; i <= DLY; i++) begin : g
      pkt_t r;
      always_ff @(posedge clk) r <= dly[i-1];
      assign dly[i] = r;
    end
  endgenerate
  modport prod (output in);
  modport cons (input dly, input clk);
endinterface

module reader (bus_if.cons s, output logic [7:0] oa, output logic [7:0] ob);
  // Read the DELAYED element (index 1) — needs the 2-element flattened wire.
  assign oa = s.dly[1].a;
  assign ob = s.dly[1].b;
endmodule

module top (
  input  logic       clk,
  input  logic [7:0] ia,
  input  logic [7:0] ib,
  output logic [7:0] oa,
  output logic [7:0] ob
);
  import p::*;
  bus_if #(.DLY(1)) bus (.clk(clk));
  assign bus.in.a = ia;
  assign bus.in.b = ib;
  reader u_reader (.s(bus), .oa(oa), .ob(ob));
endmodule
