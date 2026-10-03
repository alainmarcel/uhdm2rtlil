// PULP axi_lite_mailbox_intf, reduced.  `intf` declares an UN-OVERRIDDEN
// type parameter whose default ranges over a value parameter that IS
// overridden (`addr_t = logic [AXI_ADDR_WIDTH-1:0]`, AXI_ADDR_WIDTH 0 -> 32),
// builds a request struct over it and relays that struct two modules down.
// `mbox` instantiates its two slaves EXPLICITLY (not in a generate loop) and
// each slave hands `slv_req_i.ar.addr` to a child as a PORT ACTUAL.
// Measured in the receiving scope, where AXI_ADDR_WIDTH sits at its own
// default of 0, the member came out [-1:0] -- two bits -- and the decoder saw
// two bits of the address.  The generate-loop form and the assign-to-a-local
// form were both fine, which is why the bug hid behind every smaller repro.
module dec #(parameter type addr_t = logic) (input addr_t addr_i, output addr_t a_o);
  assign a_o = ~addr_i;
endmodule
module slave #(parameter int unsigned AxiAddrWidth = 32'd32, parameter type req_t = logic,
               parameter type addr_t = logic [AxiAddrWidth-1:0]) (
  input req_t slv_req_i, output addr_t a_o, output logic v_o);
  dec #(.addr_t(addr_t)) u_dec (.addr_i(slv_req_i.ar.addr), .a_o(a_o));
  assign v_o = slv_req_i.ar_valid;
endmodule
module mbox #(parameter int unsigned AxiAddrWidth = 32'd32, parameter type req_t = logic,
              parameter type addr_t = logic [AxiAddrWidth-1:0]) (
  input req_t [1:0] slv_reqs_i, output addr_t [1:0] a_o, output logic [1:0] v_o);
  slave #(.AxiAddrWidth(AxiAddrWidth), .req_t(req_t), .addr_t(addr_t)) u0
    (.slv_req_i(slv_reqs_i[0]), .a_o(a_o[0]), .v_o(v_o[0]));
  slave #(.AxiAddrWidth(AxiAddrWidth), .req_t(req_t), .addr_t(addr_t)) u1
    (.slv_req_i(slv_reqs_i[1]), .a_o(a_o[1]), .v_o(v_o[1]));
endmodule
module intf #(parameter int unsigned AXI_ADDR_WIDTH = 32'd0,
              parameter type addr_t = logic [AXI_ADDR_WIDTH-1:0]) (
  input  addr_t [1:0] addr, input logic [1:0][2:0] prot, input logic [1:0] v,
  output addr_t [1:0] a_o, output logic [1:0] v_o);
  typedef struct packed { addr_t addr; logic [2:0] prot; } ar_t;
  typedef struct packed { ar_t ar; logic ar_valid; } req_t;
  req_t [1:0] r;
  for (genvar i = 0; i < 2; i++) begin : g
    assign r[i] = '{ar: '{addr: addr[i], prot: prot[i]}, ar_valid: v[i]};
  end
  mbox #(.AxiAddrWidth(AXI_ADDR_WIDTH), .req_t(req_t)) u_mbox
    (.slv_reqs_i(r), .a_o(a_o), .v_o(v_o));
endmodule
module dut (input logic [1:0][31:0] addr, input logic [1:0][2:0] prot, input logic [1:0] v,
            output logic [1:0][31:0] a_o, output logic [1:0] v_o);
  intf #(.AXI_ADDR_WIDTH(32)) u (.addr(addr), .prot(prot), .v(v), .a_o(a_o), .v_o(v_o));
endmodule
