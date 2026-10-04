// PULP axi_modify_address_intf, reduced.  The parameter port list continues a
// `parameter` item with a BARE `type` item (`type addr_t = logic [W-1:0]`,
// legal: parameter_port_declaration : TYPE list_of_type_assignments).  Surelog
// handed that item to the value-parameter path: `addr_t` became a net, the
// instance carried no type parameter, and every port typed by it measured 1
// bit -- the intf's mst_aw/ar_addr_i were 1 bit and its request struct 158
// bits instead of 220.  Fixed in Surelog; this test is the ratchet for the
// bump (the slang miter fails on the previous Surelog).
module leaf #(parameter type addr_t = logic) (input addr_t a, output addr_t b);
  assign b = ~a;
endmodule
module mid #(
  parameter int unsigned W = 0,
  type addr_t = logic [W-1:0]
) (input addr_t a_i, output addr_t b_o, output logic [7:0] y);
  leaf #(.addr_t(addr_t)) u (.a(a_i), .b(b_o));
  assign y = a_i[7:0];
endmodule
module dut (input logic [31:0] a_i, output logic [31:0] b_o, output logic [7:0] y);
  mid #(.W(32)) u (.a_i(a_i), .b_o(b_o), .y(y));
endmodule
